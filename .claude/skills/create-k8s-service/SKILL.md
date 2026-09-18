---
name: create-k8s-service
description: Implement a new service on the Kubernetes stack from an approved implementation brief - Helm chart, ingress, dev secret wiring, persistence, connectsTo NetworkPolicy labels, ArgoCD Application and Tilt registration. Use after a brief has been researched and confirmed by the human. New services are always Kubernetes; never add an Ansible-managed service.
argument-hint: <brief-path>
---

# Implement a new Kubernetes service from a brief

**You do not research.** A brief has already been written and approved by the human. Your
job is to execute it faithfully. Deciding things for yourself is the failure mode this
split exists to prevent.

New services are Kubernetes only. Never create or extend an Ansible role for one.

## Where this sits

```
researcher → brief → HUMAN CONFIRMS → implementer → verifier → fixes → done
                ↑                                        │
                └──────── change requests ───────────────┘
```

Change requests go to the **researcher**, not to you. If the brief is wrong, you say so
and stop; you do not renegotiate it.

## Step 0 — Check the brief is usable

Read `$1`. Refuse to start if:

- **Status is not APPROVED.** A DRAFT or AWAITING ANSWERS brief has not passed the human
  gate.
- **Open questions remain unanswered.** The subdomain is the usual one. Never invent a
  hostname, never derive one from the service name — DNS will not exist for a guess.
- **A decision you need is missing or ambiguous.** Image tag, container port, node,
  secret decomposition, `connectsTo…` labels, storage class.

In any of those cases, stop and return a **GAPS** report naming exactly what is missing.
That routes back to the researcher. Do not look it up, do not infer it from a similar
service, do not pick a sensible default.

## Step 1 — Read the reference services

The brief names which existing services to model on and which shared helpers to use.
Read them. You are matching an established house style, not writing generic Helm.

## Step 2 — Build what the brief specifies

- **Image and tag exactly as specified.** Never `latest`.
- **Ports exactly as specified.** Do not adjust a port because it looks wrong — if you
  believe it is wrong, that is a GAPS report.
- Use the shared helpers the brief names. Duplicating what a helper produces is a defect.
- Three values files: defaults, dev, prod. `values.prod.yaml` is the only production file
  you may write to.
- Resource requests and limits, probes and `securityContext` per the conventions the
  brief records.
- Persistence: PVC with the specified size, access mode and storage class. Set `subPath`
  as specified — it is required when mounting a single file over a directory, and it must
  match a real key or path in the source volume.
- Pin the workload to the node the brief names.

## Step 3 — Ingress

Configure the hostname(s) from the brief, using the TLS and certificate mechanism the
brief records from the existing services. Do not introduce a second mechanism.

## Step 4 — Secrets

Wire dev secrets by the exact names and keys the brief gives.

**No secret value may end up in a rendered manifest.** The brief specifies how any
composite value (`DATABASE_URL`, SMTP URL, webhook URL) decomposes into separate
environment variables assembled in the container. Follow it. If the brief does not
specify a decomposition for a value that clearly carries a credential, that is a GAPS
report — not something to improvise.

Never put secret material in a ConfigMap, in `values.prod.yaml`, or in `command`/`args`.

Production secrets are out of scope. The brief lists them under Out of scope; carry them
into your report as follow-up.

## Step 5 — NetworkPolicy

Apply **only** the `connectsTo…` labels the brief specifies. Each one is an assertion
that the service needs that flow.

- Do not add a label because another service has it.
- Do not add a label to make something work. If a needed flow is not covered, that is a
  GAPS report.
- Ingress reaches the workload only from the ingress controller, on the specified port.
- Egress includes cluster DNS on UDP **and** TCP 53.
- Verify the policy selectors actually match your pod template labels. A policy matching
  nothing silently does nothing.

## Step 6 — ArgoCD and Tilt

Both, per the brief's fields. A service in neither is not deployed; a service in only one
is half-added.

## Step 7 — Render and check

```
helm template <release> <chart> -f <chart>/values.dev.yaml
```

Read the output, then grep it for leaked credentials:

```
helm template … | grep -nEi \
  'password|passwd|secret|token|api[-_]?key|://[^/[:space:]]*:[^@[:space:]]*@'
```

Apply to the dev cluster only if it is already running. If not, stay static and say live
verification was skipped.

## Step 8 — Verify (required)

Every new service is verified in a **separate context** before being reported as done:

- **Main session** → delegate to `k8s-service-verifier`, or run the `verify-k8s-service`
  skill in a fresh session.
- **Inside the `k8s-service-creator` subagent** → stop and hand back the
  `VERIFICATION REQUIRED` block. The orchestrating session runs the verifier.

Pass only:

```
service:    <name>
chart:      <path>
brief:      <brief path>
subdomains: <hostnames>
node:       <target node>
```

Do not pass your reasoning or a summary of the chart. The verifier reads the files and
the brief directly; your conclusions would only bias it.

## Step 9 — Route the findings correctly

**Only blockers force another round.** Warnings are fixed or justified in the same pass;
notes go to the human.

Classify each finding before acting on it:

- **Implementation defect** — the chart does not match the brief, or breaks a rule the
  brief assumed. Fix it: in the session holding the report if there are a handful, or by
  re-dispatching `k8s-service-creator` in **fix mode** with the findings verbatim if
  there are many.
- **Brief defect** — the chart faithfully implements the brief and the brief is wrong
  (a port that contradicts upstream, an image with no manifest for the node's
  architecture, a missing environment variable). **Do not fix this in the chart.** It
  goes back to the **researcher** as a change request, and the revised brief comes back
  through the human gate.

Getting this wrong is expensive: patching a brief defect in the chart leaves the brief
and the repository permanently disagreeing, and the next service built from that brief
repeats the error.

Then:

- Re-verify with a **fresh** verifier run. Never continue the previous one.
- **Bound the loop at two rounds.** If blockers survive the second verification, stop and
  escalate with what is open and what was tried.

## Final report

```
## New service: <service>

Brief: `.ai/briefs/<service>.md` r<n>
Subdomains: <hostnames>
Verifier: round <n> of max 2 — <n> blockers fixed, <n> warnings fixed, <n> open

### Routed back to the researcher (brief defects)

- ...

### Open findings

- ...

### Escalated (blockers surviving two rounds)

- ...

### Manual follow-up required

- [ ] DNS record for `<hostname>` — not created by me.
- [ ] Prod secret `<name>` — needed for <purpose>. Not created; out of scope for agents.
- [ ] `just <recipe>` should be run by a human to <effect>.
- [ ] Live dev verification skipped: dev cluster not running.

### Deviations from the brief

Anything you did differently, and why. Empty is the expected answer.
```
