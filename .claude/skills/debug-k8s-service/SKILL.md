---
name: debug-k8s-service
description: Diagnose a misbehaving service on the local dev or test cluster - pods not starting, not becoming ready, unreachable by hostname, failing at runtime, or wrong data. Works from the symptom through an ordered decision tree, uses the dev/test differential to localise the cause, and reports a root cause with evidence. Diagnoses only; does not fix.
argument-hint: <service> <symptom>
---

# Debug a service on dev or test

You **diagnose**. You do not fix. A fix applied mid-investigation destroys the evidence
for the next person, and the change belongs in the chart, not in the cluster.

## Scope

You work against **whichever local cluster is currently running** — dev or test,
whichever the person invoked you in. Which one it is rarely changes the diagnosis, so do
not spend effort reasoning about it. Note it in your report and move on.

**Never touch production.** If a question can only be answered against prod, say so and
stop.

Do not mutate the cluster. Diagnose, then say where the fix belongs — the change goes in
the chart, not in a live object.

## Step 0 — Confirm a cluster is there

```
kubectl config current-context
kubectl cluster-info
```

If the context is not a local cluster, or it does not respond, **stop** — this skill
assumes a running instance. Do not start one and do not switch context.

## Step 1 — Capture evidence before anything else

A restart erases the failure you were sent to explain. Collect first:

```
kubectl -n <ns> get pods -o wide
kubectl -n <ns> describe pod <pod>
kubectl -n <ns> logs <pod> --previous      # the crash you actually care about
kubectl -n <ns> get events --sort-by=.lastTimestamp
```

Never delete or restart a pod to "see if it fixes it" before the logs are captured.

## Step 2 — Follow the symptom

Start at the matching branch. Do not run the whole tree.

### Pod is not running

Read the pod status; it names the failure class.

- **Pending** — nothing scheduled it. Check `nodeSelector`/affinity against the node
  labels, taints without matching tolerations, and whether the PVC is bound. A PVC on
  node-local storage plus a pod pinned elsewhere is the classic version.
- **ImagePullBackOff / ErrImagePull** — wrong repository, wrong tag, or the tag has no
  manifest for this node's **architecture**. The nodes differ; check the manifest list
  before blaming the registry.
- **CreateContainerConfigError** — an absent secret or ConfigMap, or a `secretKeyRef`
  naming a key that does not exist. Compare the reference against the actual object key
  by key; a typo here never surfaces as a template error.
- **CrashLoopBackOff** — the application started and exited. `logs --previous` is the
  whole answer most of the time. Common causes: a missing required environment variable,
  a config file mounted over its own directory because `subPath` was omitted, or a
  volume the container's user cannot write to.
- **Init/sidecar stuck** — an init container waiting on a dependency it cannot reach.
  That is usually a network policy question; jump to the network branch.

### Pod runs but never becomes Ready

- Probe path, port and scheme against what the application actually serves. A probe
  pointed at the wrong port fails forever and reads as an application fault.
- `initialDelaySeconds` shorter than the real startup time, on a service that is slow to
  boot.
- The container listens on localhost only, so the probe from the kubelet cannot reach it.

### Not reachable by hostname

Work outwards, and stop at the first layer that fails:

1. `kubectl port-forward` straight to the pod — does the app answer at all?
2. Service endpoints: `kubectl -n <ns> get endpoints <svc>`. Empty means the Service
   selector does not match the pod labels.
3. Service `targetPort` against the real container port.
4. Ingress object: hostname spelling, router rule, entrypoint, TLS configuration.
5. Certificate state — issued, or stuck?
6. DNS for the hostname. In test especially, the record may simply not exist.

### Runs, but fails when it talks to something

This is where the `connectsTo…` labels bite. A missing label produces a **silent drop**,
not a refusal, so the application reports a timeout and looks broken internally.

- List the `connectsTo…` labels the pod carries against the flows it actually needs.
- Confirm each label matches a policy that exists. A label with no matching policy
  permits nothing while looking like it does.
- Check egress to cluster DNS covers **UDP and TCP 53**. UDP-only works for months and
  then fails on a truncated response — intermittent resolution failures are this, until
  proven otherwise.
- Confirm policy `podSelector`s actually match the pod's labels. A policy matching
  nothing silently does nothing.
- Only then look at the dependency itself.

### Data is missing or wrong

- Is the PVC bound, and is it the one you think? Compare against what the service used
  before.
- `subPath`: a value that does not exist in the source volume mounts an **empty
  directory** rather than failing, so the data looks deleted. On a PVC, a changed
  `subPath` repoints at a different subdirectory with the same effect.
- Ownership and permissions: `fsGroup`/`securityContext` against the UID the container
  runs as.
- Files mounted with `subPath` do not receive ConfigMap or Secret updates. A config that
  "did not take effect" is often this.

## Step 3 — Confirm the cause

One hypothesis, one test. Do not change three things and declare victory.

Prefer evidence that does not mutate anything: `helm template` and read the rendered
YAML, `kubectl describe`, `kubectl get -o yaml`, `logs --previous`, `port-forward`,
`kubectl exec` for a read-only check. Use upstream documentation to confirm what the
application expects rather than assuming.

If you must change something to test a hypothesis, do it **in dev only**, say so
explicitly, and state what you changed so it can be undone.

## Step 4 — Report

```
## <service> — <symptom>

Cluster: <context>

### Root cause
One sentence. If you could not establish one, say that plainly and list what you ruled
out — a confident wrong answer costs more than an honest gap.

### Evidence
- <command or file> → <what it showed>

### Fix belongs in
- `<chart file>:<line>` — <change>, or
- the brief (`briefs/<service>.md`) — the decision itself was wrong, or
- cluster/infra configuration, or
- upstream — <issue link>

### Ruled out
- ...

### Not checked
- ... and why
```

Name the file and line. "Check the network policy" is not a diagnosis.
