---
name: research-k8s-service
description: Research a new Kubernetes service and produce the implementation brief that the implementer will execute - upstream image, tag, architecture, ports, environment variables, persistence, dependencies, plus the repository conventions, connectsTo labels and open questions for the human. Use before any new service is implemented, and again whenever the human requests changes to a brief.
argument-hint: <service> [upstream-docs-url]
---

# Research a service and write its implementation brief

You do the finding-out. The implementer does not research — it executes what you write,
so anything you leave vague becomes a guess in production.

Your output is a **file**, not a summary. Write it to `.ai/briefs/<service>.md` and return
the path plus a short digest. The human reads the file verbatim at the confirmation
gate; a lossy summary would defeat that.

## Revision mode

If you were given an existing brief plus change requests, you are revising, not starting
over:

- Apply the requested changes and update anything they invalidate — a changed image tag
  may change the ports, the environment variables and the architecture support.
- Do not silently rewrite decisions the human did not ask you to touch.
- If a change request conflicts with upstream reality, say so in the brief rather than
  quietly implementing something that cannot work.
- Record what changed in the brief's changelog, and re-answer any open questions the
  human resolved.

## Step 1 — Extract the repository conventions

Read the services already on the stack, end to end: charts, values files, ArgoCD
Applications, Tilt entries, NetworkPolicy definitions. These are the standard the new
service must match, and they override any generic Helm practice you know.

Record concretely, with paths:

- chart layout, file naming, values-file split
- which shared helpers exist and what each generates
- label, annotation and naming scheme
- how ingress hostnames, TLS and certificates are configured
- how secrets are named and referenced
- **the exact set of `connectsTo…` labels defined**, and which policy each one satisfies
- resource requests/limits, probes and `securityContext` conventions
- storage classes available and what the existing services use

## Step 2 — Research upstream

Use web search and fetch. Establish, for a specific version:

- image repository and a concrete tag — never `latest`
- whether that tag publishes a manifest for the target node's **architecture**
- the port the container actually listens on, and any secondary ports
- required and recommended environment variables, including which carry secrets
- paths that must persist, and which need `subPath`
- dependencies: database, cache, broker, and what the service expects to reach them on
- whether it needs egress beyond the cluster, and to where
- known pitfalls, breaking changes and migration notes for that version

Cite a URL for each fact. A claim without a source is one the verifier will have to
re-derive, and it may reach a different answer.

## Step 3 — Make the repository-side decisions

- Target node, with the reason, and confirmation the image supports its architecture.
- Which `connectsTo…` labels the service needs — **each one justified by a specific
  flow**. If a flow no existing label covers is required, say so; do not propose a
  permissive policy.
- Secret names and keys, and for any composite value (`DATABASE_URL`, SMTP URL) the
  exact decomposition into environment variables so the credential never appears in a
  rendered manifest.
- Persistence: PVC size, access mode, storage class, mount paths and `subPath` values.
- Which shared helpers the implementer should use, by name.
- ArgoCD Application fields and the Tilt entry shape, matching the existing services.

## Step 4 — Open questions

Anything you cannot determine goes here, not into a guess. Always include the
**subdomain(s)** unless the human already stated them — never invent a hostname or
derive one from the service name.

Typical open questions: subdomains, node preference, persistence size, whether external
egress is acceptable, which existing service this should be modelled on when two differ.

The human answers these at the confirmation gate, and the answers come back to you as
change requests.

## Brief format

Write exactly this structure to `.ai/briefs/<service>.md`:

```
# Implementation brief: <service>

Revision: <n> · Status: DRAFT | AWAITING ANSWERS | APPROVED

## Summary
One paragraph: what the service is and what it will look like on the stack.

## Decisions
Authoritative. The implementer follows these and does not re-derive them.

| Item | Value | Source |
| ---- | ----- | ------ |
| Image | `repo:tag` | <url> |
| Architectures | amd64, arm64 | <url> |
| Container port | 8080 | <url> |
| Node | <node> | repo convention |
| Subdomain(s) | <host> | human |
| Storage class / size | <...> | existing services |
| connectsTo labels | `connectsToX` — needed for <flow> | <policy path> |
| Shared helpers | `<helper>` at `<path>` | existing services |

### Environment variables
| Name | Value or source | Secret? |

### Persistence
| Mount path | subPath | Size | Notes |

### Ingress
Hostname, TLS mechanism, router/entrypoint, following `<reference service>`.

### ArgoCD and Tilt
Exact fields and paths, following `<reference service>`.

## Open questions
Must be answered before implementation.
- [ ] ...

## Out of scope
- Production secrets: `<name>` needed for <purpose> — a human creates it.
- DNS record for `<hostname>` — a human creates it.

## Uncertainties
Facts I could not confirm, flagged for the verifier to re-check independently.
- ...

## Changelog
- r1: initial
- r2: <what the human asked to change, and what it invalidated>
```

## What not to do

- Do not write chart files, values files or manifests. You produce the brief only.
- Do not leave a decision implicit because it "follows from" another one. The
  implementer has an empty context and no web access.
- Do not present a preference as a finding. If two approaches are defensible, name both
  and recommend one with a reason.
