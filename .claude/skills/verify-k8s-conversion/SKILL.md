---
name: verify-k8s-conversion
description: Independently verify a service that has been converted from an Ansible role to a Helm chart. Checks parity with the source role, node placement, dev secret wiring, secret leakage into rendered manifests, volume and subPath correctness, use of common templates, Tilt and ArgoCD registration, NetworkPolicy strictness, and image/port correctness against upstream sources. Run after every conversion, before review.
---

# Verify an Ansible-to-Kubernetes conversion

You are verifying someone else's work. Assume nothing they tell you about the chart is
true — read the files. Report findings; do not fix anything.

## Inputs

You should have been given:

- `service` — the service name
- `chart` — path to the converted Helm chart
- `role` — path to the Ansible role it was converted from
- `node` — which node the service is supposed to run on
- `task` — path to the conversion task file, if one exists

If any are missing, locate them yourself and say which you inferred. Read the Ansible
role first — it is the source of truth for what this service currently needs in
production. Do not edit it.

## Verdicts

Tag every finding:

- **BLOCKER** — data loss, secret exposure, or the service cannot work. Must be fixed.
- **WARNING** — works but is wrong, fragile, or violates a repository convention.
- **NOTE** — worth a human's attention; no action strictly required.

Return findings only. No summary of what the chart does, no praise, no restating the
checklist. If a section passes, one line: `OK`.

---

## 1. Parity with the Ansible role

Build a table from the role, then check each row against the chart:

| From the role                          | Present in chart? |
| -------------------------------------- | ----------------- |
| every environment variable             |                   |
| every volume / bind mount              |                   |
| every published port                   |                   |
| run-as user / UID / GID                |                   |
| capabilities, privileged flags         |                   |
| config files and templates             |                   |
| dependent services (db, cache, broker) |                   |

Anything in the role but not the chart is a **BLOCKER** unless the conversion task file
explicitly says it was dropped. Silent omissions are the main failure mode of this
migration — a missing volume means data loss on first deploy.

Healthchecks are explicitly not required in the k8s setup for now. Don't flag
inconsistencies regarding healthchecks. They are **OK**.

## 2. Node placement

- `nodeSelector` / `affinity` pins the workload to the intended node. A chart with no
  placement constraint is a **BLOCKER** unless the service is genuinely node-agnostic.
- The nodes differ in **CPU architecture**. Confirm the image publishes a manifest for
  the target node's architecture (see §8). Wrong-arch images fail at pull time, long
  after review.
- If storage is node-local (`hostPath`, local PV), the pod **must** be pinned to the
  node holding the data. Node-local storage with a free-floating pod is a **BLOCKER**.
- Tolerations present if the target node carries taints.

## 3. Secrets — dev wiring

- Every secret the role supplies has a corresponding dev secret, and the chart
  references it by the **exact name and key** that exists in the dev cluster. A typo'd
  `secretKeyRef` surfaces as `CreateContainerConfigError`, not as a template failure.
- `envFrom.secretRef` vs `env[].valueFrom.secretKeyRef` — either is fine, but a key
  listed in `values.yaml` and not present in the secret is a **BLOCKER**.
- No secret material sits in a `ConfigMap`. In fact, config-maps should not be used.
  All non-secret configuration should be done directly in the helm values files,
  preferably in the environment agnostic one, if the value is equivalent in both dev
  and prod. The only exception is content, that cannot be represented as a helm value.
- Optional-vs-required is set correctly; a required secret marked `optional: true`
  starts a broken pod silently.

## 4. Secrets — leakage into rendered manifests

**No secret value may appear in rendered output.** Verify by rendering, not by reading
templates:

```
helm template <release> <chart> -f <values> | grep -nEi \
  'password|passwd|secret|token|api[-_]?key|private[-_]?key|://[^/[:space:]]*:[^@[:space:]]*@'
```

The last pattern catches credentials embedded in URLs, which is the case that slips
through. Composite connection strings are the trap:

> **Example — the kimai server.** An app that wants a single
> `DATABASE_URL=mysql://user:password@host:3306/db` cannot have that string built in
> `values.yaml`, because the password would land in the rendered manifest and in git.
> The fix is to pass the components as separate environment variables sourced from the
> secret, and assemble the URL inside the container — or to store the whole assembled
> URL as a secret key and reference it with `secretKeyRef`. Introducing extra
> environment variables to keep the secret out of the template is expected and correct;
> flag any chart that took the shortcut instead.

Check the same for: SMTP URLs, S3/backup credentials, OIDC client secrets, webhook URLs
containing tokens, and any `--flag=value` style args in `command`/`args`.

Also confirm `values.prod.yaml` contains **no** secret material. If the conversion needs
a new or changed production secret, that is not a defect — record it under Manual
follow-up so a human creates it.

## 5. Volumes, mounts and `subPath`

For every mount:

- `mountPath` matches what the application actually expects. Cross-check against
  upstream documentation, not against the Ansible role alone — paths sometimes change
  between the packaged version and the image.
- **`subPath` is correct.** Specifically:
  - Mounting a single file from a ConfigMap or Secret **requires** `subPath`; without
    it the whole directory is replaced and the application loses its other files. This
    is a **BLOCKER** when it shadows a directory the app needs.
  - `subPath` must match a real key or path within the source volume. A `subPath` that
    doesn't exist mounts an empty directory rather than failing loudly.
  - Files mounted with `subPath` **do not receive updates** when the ConfigMap or Secret
    changes. If the chart relies on hot-reload of a mounted config, flag it.
  - For PVCs, `subPath` carves out a subdirectory — check it matches the layout the
    Ansible role established, or existing data will appear to have vanished.
- `readOnly: true` wherever the app doesn't write.
- PVC `accessModes`, `storageClassName` and `size` are set deliberately, not defaulted.
- The container's user can actually write to the volume — `fsGroup` / `securityContext`
  consistent with the UID the role ran the service as.

## 6. Common templates

- Shared chart helpers / the common library chart are used where applicable.
  Hand-rolled boilerplate that duplicates an existing helper is a **BLOCKER**; list
  which helper should have been used.
- Labels, selectors and naming come from the shared helpers so they stay consistent
  across services.
- If a helper was deliberately bypassed, the reason should be stated in the chart or
  the task file. An unexplained bypass is a **WARNING**.

## 7. Tilt and ArgoCD

A chart is not converted until both are wired:

- **Tilt** — the service is registered in the Tilt configuration, points at the right
  chart and dev values, declares its resource dependencies, and comes up with
  `tilt up` without manual steps.
- **ArgoCD** — an Application manifest exists with the correct source path, target
  revision, destination namespace and cluster, and a sync policy consistent with the
  other services. Check `ignoreDifferences` if the app mutates its own resources.
- The destination cluster is the intended one. An Application pointed at the wrong
  destination is a **BLOCKER**.

## 8. Images and ports — verify against upstream

This section needs external lookups. Use them.

- **Image repository and tag exist**, and the tag is pinned. `latest` is a **BLOCKER**.
- **Multi-arch**: the tag publishes a manifest for the target node's architecture.
- **Ports**: the `containerPort`, Service `port`/`targetPort` and any probe ports match
  the ports the upstream project documents. Do not trust the port in the Ansible role
  alone — it may reflect a host-side mapping rather than the container's own port.
- **Required environment variables**: compare against upstream documentation for the
  pinned version. Report required variables that are absent, and variables in the chart
  that upstream has renamed or deprecated.
- Note any upstream breaking changes between the version the role deploys and the
  version the chart pins.

## 9. NetworkPolicy — hardened by default

The target is deny-by-default with narrow explicit exceptions.

- A **default-deny** policy covers both ingress and egress for the namespace. Its
  absence is a **BLOCKER** for a hardened setup.
- **Ingress**: only from the ingress controller, selected by namespace and pod selector,
  on the specific container port. An empty `podSelector: {}` allow-all rule, or ingress
  from the whole cluster, is a **BLOCKER**.
- **Egress**: DNS to the cluster DNS service on UDP **and** TCP 53 — TCP is the one
  people forget, and it breaks large responses intermittently. Then only the specific
  peers the service needs (database, cache, object storage), selected by pod/namespace
  label, on their specific ports.
- `0.0.0.0/0` egress is a **WARNING** even when the service genuinely needs the
  internet. Narrow to the required ports at minimum; prefer a CIDR where the endpoint
  is stable. If it must stay open, say why in the finding so the human can accept it.
- Policies select the workload correctly — a NetworkPolicy whose `podSelector` matches
  nothing silently does nothing. Verify the labels match the pod template.

## 10. Completeness check — verify that everything was created

Make sure that all relevant files were generated during the conversion phase. Every
fully converted service owns exactly these artifacts, in rare cases even more.

- `deploy/kubernetes/apps/<name>/Chart.yaml` (+ `Chart.lock` once `common` is pinned)
- `deploy/kubernetes/apps/<name>/values.yaml`, `values.dev.yaml`, `values.prod.yaml`
- `deploy/kubernetes/apps/<name>/templates/*.yaml` (including `secrets.yaml`, which globs `secrets/*.<env>{.enc,}.yaml`)
- `deploy/kubernetes/apps/<name>/secrets/secret.dev.yaml` and `secret.prod.enc.yaml`
- `deploy/argocd/apps/<name>.yaml`
- A `helm(...)` block in `deploy/tilt/Tiltfile.bzl`

---

## Output format

```
## Verification: <service>

### Blockers

- [§4] `charts/<svc>/values.dev.yaml:12` — DATABASE_URL contains the password inline;
  it appears in rendered output. Split into components sourced from secret `<name>`.

### Warnings

- [§9] No egress rule for TCP 53; DNS will fail on truncated responses.

### Notes

- [§8] Upstream renamed `FOO_BAR` to `FOO__BAR` in v2.3; chart pins v2.4.

### Manual follow-up

- [ ] Prod secret `<name>` must be created with keys `<...>`. Not created — out of scope.

### Checked and OK

§1 parity · §2 node placement · §5 mounts · §6 common templates · §7 tilt/argocd
```

Be specific: file and line for every finding, and a concrete fix. "Review the network
policy" is not a finding. If you could not check something — no cluster, no upstream
docs found — say so explicitly rather than passing it silently.
