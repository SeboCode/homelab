---
name: verify-k8s-service
description: Independently verify a newly added Kubernetes service - consistency with the existing services, pinned image and correct architecture, ports checked against upstream, dev secret wiring, secret leakage in rendered manifests, persistence and subPath, ingress and subdomain, connectsTo NetworkPolicy labels, ArgoCD and Tilt registration. Run after every new service is created, before review.
---

# Verify a new Kubernetes service

You are verifying someone else's work. Assume nothing you were told about the chart is
true — read the files. Report findings; do not fix anything.

## Inputs

- `service` — the service name
- `chart` — path to the Helm chart
- `brief` — path to the implementation brief the chart was built from
- `subdomains` — the hostname(s) it should serve
- `node` — the intended node

Locate anything missing yourself and say which you inferred.

## Two questions, not one

Read the brief, then answer both separately:

1. **Does the chart match the brief?** A divergence is an implementation defect.
2. **Is the brief right?** You have web access and the implementer did not, so you are
   the first check on the research. A port, image tag, architecture or required
   environment variable that contradicts upstream is a **brief defect**.

Tag every finding `[impl]` or `[brief]`. They route differently: implementation defects
are fixed in the chart, brief defects go back to the researcher and through the human
gate. Mislabelling one leaves the brief and the repository permanently disagreeing.

Pay particular attention to the brief's **Uncertainties** section — the researcher
flagged those precisely because they could not be confirmed. Confirm them independently
rather than accepting them.

**Read the existing services first.** A new service is measured against them, not
against generic Helm practice. Their chart layout, helper usage, labels, ingress and
secret patterns are the standard this chart has to meet.

## Verdicts

- **BLOCKER** — data loss, secret exposure, exposed-by-default networking, or the
  service cannot work.
- **WARNING** — works but is wrong, fragile, or inconsistent with the other services.
- **NOTE** — worth a human's attention; no action strictly required.

Findings only. If a section passes, one line: `OK`.

---

## 1. Consistency with the existing services

- Directory layout, file naming and values-file split match.
- Shared helpers used where they apply. Duplicated boilerplate that a helper already
  produces is a **WARNING**; name the helper that should have been used.
- Labels, selectors, annotations, probes, resource requests/limits and
  `securityContext` follow the established scheme.
- An unexplained divergence from both existing services is a **WARNING** even when the
  chart is technically correct.

## 2. Image

- The repository and tag exist.
- **The tag is pinned. `latest` is a BLOCKER** — it makes rollbacks meaningless and
  turns a restart into an unplanned upgrade.
- The tag publishes a manifest for the target node's **architecture**. The nodes differ;
  a wrong-arch image fails at pull time, long after review.
- `imagePullPolicy` is consistent with a pinned tag.

## 3. Ports — verified against upstream

- The `containerPort` is the port the application actually listens on according to
  upstream documentation for the pinned version — not a port carried over from a similar
  service.
- Service `port`/`targetPort` and any probe ports agree with it.
- The ingress routes to the right Service port.
- Mismatched probe ports are a **BLOCKER**: the pod never becomes ready and the failure
  reads as an application problem.

## 4. Secrets — dev wiring

- Every referenced secret exists in dev with the **exact name and key** used in the
  chart. A typo surfaces as `CreateContainerConfigError`, not as a template failure.
- There are no optional secrets.
- No secret material in a ConfigMap.
- Required environment variables from upstream documentation are all present.

## 5. Secrets — leakage into rendered manifests

Verify by rendering, not by reading templates:

```
helm template <release> <chart> -f <values> | grep -nEi \
  'password|passwd|secret|token|api[-_]?key|private[-_]?key|://[^/[:space:]]*:[^@[:space:]]*@'
```

The URL pattern catches credentials embedded in connection strings, which is the case
that slips through review — a `DATABASE_URL` or SMTP URL reads as one innocuous value in
`values.yaml`. Any credential in rendered output is a **BLOCKER**; the fix is separate
environment variables assembled in the container, or a `secretKeyRef` to the whole
string.

Check the same for `command`/`args`, and confirm `values.prod.yaml` holds no secret
material.

## 6. Persistence, mounts and `subPath`

- Everything upstream says must persist is on a PVC. A stateful service running on
  `emptyDir` is a **BLOCKER**.
- PVC `size`, `accessModes` and `storageClassName` are set deliberately, not defaulted.
- `mountPath` matches what the application expects per upstream docs.
- **`subPath`**: required when mounting a single file over a directory — without it the
  whole directory is replaced and the app loses its other files. It must match a real
  key or path in the source volume; a `subPath` that does not exist mounts an empty
  directory rather than failing. Files mounted with `subPath` do not receive
  ConfigMap/Secret updates, so flag any chart relying on hot-reload.
- `readOnly: true` wherever the app does not write.
- The container's user can write to the volume — `fsGroup`/`securityContext` consistent
  with the UID it runs as.

## 7. Ingress and subdomain

- The hostname matches what the human asked for, exactly. A guessed or auto-derived
  hostname is a **BLOCKER** — DNS will not exist for it.
- TLS and certificate issuance follow the same mechanism as the existing services. A
  second mechanism introduced alongside the established one is a **WARNING**.
- The router rule, entrypoint and any middleware match the house pattern.
- The DNS record is a human action — confirm it is listed as follow-up rather than
  assumed.

## 8. NetworkPolicy and `connectsTo…` labels

Target is deny-by-default with narrow, justified exceptions.

- Default-deny covers ingress **and** egress. Its absence is a **BLOCKER**.
- Enumerate the `connectsTo…` labels actually defined in this repository, then check the
  workload's labels against them:
  - Every label the pod carries corresponds to a flow the service genuinely needs. A
    label applied without a matching requirement is a **WARNING** — it is a silent hole.
  - A label set copied wholesale from another service is a **WARNING** even if it works.
  - A label that does not match any defined policy is a **BLOCKER**: it looks like the
    flow is permitted and it is not, so the failure appears at runtime.
- Ingress reaches the workload only from the ingress controller, on the specific port.
- Egress includes cluster DNS on UDP **and** TCP 53. UDP-only passes every manual test
  and then fails intermittently on truncated responses.
- `0.0.0.0/0` egress is a **WARNING** even when the service needs the internet; narrow
  by port at minimum, and say why it must stay open so a human can accept it.
- Policy `podSelector`s actually match the pod template labels. A policy matching
  nothing silently does nothing.

## 9. Node placement

- `nodeSelector`/affinity pins the workload to the intended node. No placement
  constraint is a **BLOCKER** unless the service is genuinely node-agnostic.
- Node-local storage with a free-floating pod is a **BLOCKER**.
- Tolerations present if the target node carries taints.

## 10. ArgoCD and Tilt

- **ArgoCD**: Application manifest exists, with correct source path, target revision,
  destination namespace and cluster, and a sync policy consistent with the other
  services. A wrong destination is a **BLOCKER**.
- **Tilt**: registered in the dev loop, pointing at the right chart and dev values, with
  its dependencies declared.
- Missing either one is a **BLOCKER**.

## 11. Completeness check — verify that everything was created

Make sure that all relevant files were generated during the implementation phase. Every
fully implemented service owns exactly these artifacts, in rare cases even more.

- `deploy/kubernetes/apps/<name>/Chart.yaml` (+ `Chart.lock` once `common` is pinned)
- `deploy/kubernetes/apps/<name>/values.yaml`, `values.dev.yaml`, `values.prod.yaml`
- `deploy/kubernetes/apps/<name>/templates/*.yaml` (including `secrets.yaml`, which globs `secrets/*.<env>{.enc,}.yaml`)
- `deploy/kubernetes/apps/<name>/secrets/secret.dev.yaml` and `secret.prod.enc.yaml`
- `deploy/argocd/apps/<name>.yaml`
- A `helm(...)` block in `deploy/tilt/Tiltfile.bzl`

---

## Output format

```
## Verification: <service> (brief r<n>)

### Blockers
- [impl][§5] `<chart>/values.dev.yaml:14` — SMTP URL embeds the password; it appears in
  rendered output. Split into components sourced from secret `<name>`.
- [brief][§3] Brief specifies port 8080; upstream documents 3000 for the pinned version
  (<url>). Chart follows the brief correctly — the brief needs revising.

### Warnings
- [impl][§8] Pod carries `connectsToDatabase` but the brief lists no database flow.

### Notes
- [brief][§2] Upstream released v3.2 with a security fix; brief pins v3.1.

### Manual follow-up
- [ ] DNS record for `<hostname>` — not created.
- [ ] Prod secret `<name>` with keys `<...>` — not created; out of scope.

### Checked and OK
§1 consistency · §2 image · §6 persistence · §9 placement · §10 argocd/tilt
```

File and line for every finding, and a concrete fix. "Review the network policy" is not
a finding. If you could not check something — no cluster, no upstream docs — say so
rather than passing it silently.
