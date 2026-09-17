---
name: convert-ansible-to-k8s
description: Convert a service from its Ansible role to a Helm chart - parity extraction, node placement, dev secret wiring, volumes and subPaths, common templates, Tilt and ArgoCD registration, and a deny-by-default NetworkPolicy. Use when porting any service to Kubernetes.
argument-hint: <service> [task-file]
---

# Convert a service from Ansible to Kubernetes

## Before you start

1. Read the conversion task file if one exists (`$2`, or find it). Task files written
   in earlier sessions carry decisions already made — follow them, and say so if you
   disagree rather than quietly diverging.
2. Read the Ansible role for `$1`. It is the **source of truth** and is **read-only** —
   it still runs this service in production. Port from it; never edit it.
3. Read one recently converted chart as the reference implementation. Match its
   structure rather than inventing a new one.

## Step 1 — Extract parity facts

Before writing any YAML, write down what the role actually provides:

- environment variables (and which are secret)
- volumes, their host paths, and what lives in them
- ports, distinguishing the container's own port from any host mapping
- the user/UID the service runs as
- capabilities, config files, dependent services

Keep this list. It is what the verifier will check the chart against, and it is the
thing that gets silently truncated if you skip it.

Healthchecks are explicitly not required in the k8s setup for now.

## Step 2 — Decide placement

Pick the target node and pin it with `nodeSelector` or affinity. Confirm the image
publishes a manifest for that node's architecture — the nodes differ. If the service
owns node-local data, the pod must be pinned to the node holding it.

## Step 3 — Write the chart

- Use the **common template helpers** wherever they apply. Do not hand-roll what a
  helper already produces. If you bypass one, write down why.
- `values.yaml` for defaults, `values.dev.yaml` for dev, `values.prod.yaml` for prod
  overrides. `values.prod.yaml` is the only production file you may write to.
- Prefere adding non-secret values to the helm values file instead of using config-maps.
  The only exception is when a value cannot be represented as a helm value entry.
- Pin the image tag. Never `latest`.
- Mounts: match the paths the application expects, and set `subPath` correctly —
  required when mounting a single file, and it must match a real key or path in the
  source volume.

## Step 4 — Secrets

Wire dev secrets by exact name and key. Then the rule that matters:

**No secret value may end up in a rendered manifest.** Composite values are where this
breaks — a `DATABASE_URL` or SMTP URL with the password inline cannot be built in a
values file. Pass the components as separate environment variables sourced from the
secret and assemble them in the container, or store the assembled string as a secret
key and reference it. Adding extra environment variables to keep a secret out of the
template is the correct trade, not a workaround. The kimai server is the worked example
in this repository.

If the conversion requires a new or changed **production** secret: do not create it.
Continue with everything else and record it under Manual follow-up.

## Step 5 — NetworkPolicy

Write it deny-by-default and open only what is needed:

- default-deny for ingress and egress
- ingress only from the ingress controller, by namespace + pod selector, on the exact port
- egress to cluster DNS on UDP **and** TCP 53, plus the specific peers the service needs
- no blanket `0.0.0.0/0` egress unless the service truly needs the internet, and then
  narrowed by port

## Step 6 — Tilt and ArgoCD

Register the service in the Tilt configuration and add its ArgoCD Application manifest.
The conversion is not finished without both.

## Step 7 — Render and self-check

```
helm template <release> charts/<service> -f charts/<service>/values.dev.yaml
```

Read the output. Then grep it for leaked credentials before going further. Apply to the
dev cluster only if it is running; if it is not, stay with static verification and note
that live verification was skipped.

## Step 8 — Run the verifier (required)

**Every conversion ends here**, but who triggers it depends on where you are running:

- **Main session** → delegate to the `ansible-to-k8s-verifier` subagent, or run the
  `verify-k8s-conversion` skill in a fresh session if the harness has no subagents.
- **Inside the `ansible-to-k8s-converter` subagent** → stop and hand back with the
  `VERIFICATION REQUIRED` block. Do not try to dispatch the verifier yourself. The
  orchestrating session runs it.

Either way, the verifier receives only these, and nothing else:

```
service: <name>
chart:   charts/<service>
role:    <path to the ansible role>
node:    <target node>
task:    <path to task file, if any>
```

Do **not** pass your reasoning, your summary of the chart, or an assurance that
something is fine. The verifier exists to catch what you believe and got wrong; feeding
it your conclusions defeats the isolation. Let it read the files itself.

## Step 9 — Act on the findings

**Only blockers force another round.** Warnings are fixed or justified in the same pass;
notes go to the human. A stylistic quibble is not worth a verification cycle.

Who does the fixing:

- **Simple typos or stylistic changes or when no subagent was used** → fix them in the
  session holding the verifier's report. They are usually mechanical, and delegating
  costs more context than it saves.
- **More complex findings** → re-dispatch the `ansible-to-k8s-converter` subagent in
  **fix mode**, passing the findings verbatim in the prompt. Do not re-dispatch it
  without them — it starts with an empty context and will redo the conversion from
  scratch, reintroducing the same defect.

Then:

- Fix every **BLOCKER**. Fix **WARNINGS** unless there is a reason not to; state it.
- If you disagree with a finding, say so explicitly and explain. A dismissed finding
  that never reaches the human is worse than a false positive.
- **Re-verify with a fresh verifier run.** Never continue the previous one — a verifier
  holding its own earlier findings confirms the fix instead of looking again, and the
  fix is exactly what needs checking. Mount and NetworkPolicy changes routinely break
  something adjacent.

**Bound the loop at two rounds:** convert → verify → fix → verify → stop. If blockers
survive the second verification, stop and escalate to the human with what is still open
and what was tried. Do not keep cycling.

## Final report

```
## Converted: <service>

Verifier: round <n> of max 2 — <n> blockers fixed, <n> warnings fixed, <n> left open

### Escalated (blockers surviving two rounds)
- ...

### Open findings
- ...

### Manual follow-up required
- [ ] Prod secret `<name>` — needed for <purpose>. Not created; out of scope for agents.
- [ ] `just <recipe>` should be run by a human to <effect>.
- [ ] Live dev verification skipped: dev cluster not running.

### Disagreed with
- ...
```
