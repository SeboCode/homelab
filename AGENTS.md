# AGENTS.md

Instructions for any AI coding agent working in this repository. Harness-agnostic:
nothing here depends on a specific agent tool. Tool-specific entrypoints (`CLAUDE.md`,
`.cursorrules`, etc.) should reference this file rather than duplicate it.

## What this repository is

Infrastructure automation for a private homelab across two nodes:

- **Ansible** configures the **nodes** themselves (OS, users, packages, ssh, etc.).
- **Kubernetes** deploys the **service stacks** on top of those nodes.

## IMPORTANT

The repository is **mid-transition**. Production still runs on the Ansible-managed
service layer while the Kubernetes layer is being built out. Both exist side by side,
and the Ansible side is load-bearing right now. In the future, this will change. No
new services are added in the Ansible setup.

## Environments

| Environment | Cluster           | Agent access                                     |
| ----------- | ----------------- | ------------------------------------------------ |
| `dev`       | local dev cluster | read/write, when the cluster is actually running |
| `prod`      | homelab nodes     | **no connection, ever**                          |

## Hard rules

These are non-negotiable. If a task appears to require breaking one, stop and report
rather than working around it.

### 1. Never connect to production

Do not run any command that targets a production cluster, node, or host. Do not switch
kube contexts to a production context, do not SSH to a node, do not reach a production
service over the network. If the only way to verify something is against production,
say so and stop.

### 2. Never modify production values — except prod Helm values files

The single exception: **`values.prod.yaml`** files (Helm production value overrides) may
be edited. Everything else production-scoped is read-only — inventory, host variables,
production-specific Ansible configuration, and anything holding production state.

### 3. Never add or modify production secrets — mention them instead

If a change requires a new or changed production secret, **do not create, edit, or
generate it**. Carry out the rest of the work as normal, then report the requirement
explicitly (see [Reporting](#reporting)). A missing secret is never a reason to stop
work; it is a reason to write it down.

### 4. Never execute `just` recipes or the scripts that are being executed by `just`, i.e. scripts under /scripts

The `justfile` is a **human-only** entrypoint. Do not run `just <anything>`. The scripts
that the `just` recipes invoke are also not to be executed. Most of them cannot be run
anyway, as they require secrets for a successfull invocation.

Reading the `justfile` and the scripts is encouraged — it is the best documentation of
how this project is actually operated. What is not allowed is bypassing this rule by
copying a recipe's body and running the underlying commands yourself. If a recipe would
be useful to run, name it and let a human run it.

### 5. Never run Ansible

No `ansible`, `ansible-playbook`, `ansible-galaxy`, or equivalent — not against
production, not against a local VM, not in check mode. The execution is too time
consuming and secret information is always required to run it.

### 6. Do not touch Ansible **service** files

The Ansible service layer still runs production during the transition. Treat
service-related Ansible roles, tasks, templates, and their variables as read-only.

Read them freely — when porting a service to Kubernetes, the Ansible role is the
source of truth for what that service currently needs (volumes, environment, ports,
users, capabilities). Port _from_ it; never edit it.

This restriction covers service files only. The rest of the Ansible tree — node
configuration, bootstrap, common roles, inventory structure — is normal editable code,
subject to the production-values rule above. You still may not _run_ Ansible (rule 5).

### 7. Kubernetes: dev cluster only, and only when it is up

You may check whether the dev cluster is reachable — that check is explicitly allowed.
Something like:

```
kubectl config current-context
kubectl cluster-info
```

Then:

- **Context is the dev cluster and it responds** → `kubectl` is fine for read
  operations and for applying to dev.
- **Cluster is not running** → do not start it, do not prompt for it, and do not fall
  back to any other context. Continue with static verification (below) and note in your
  report that live verification was skipped.
- **Context is anything other than dev** → run nothing. Report it.

Never pass `--context`, `--kubeconfig`, or `--server` to reach a different cluster than
the one already configured.

### 8. Ignore `README.md`

The README is **out of date and must not be treated as a source of truth**. It describes
the pre-Kubernetes service layer and the previous node operating systems. Do not read it
for context, do not cite it, do not copy conventions or tables from it, and do not update
it piecemeal.

It will be rewritten once the Kubernetes transition is complete and both nodes have been
moved to Debian. Until then, this file plus the code itself are the only sources of truth.

## Verification

**Prefer static rendering over live cluster operations, except if the dev cluster is running.**
Rendered output is deterministic, reviewable, and requires no cluster at all.

In rough order of preference:

1. `helm template` — render the chart with the relevant values file and read the result.
   This is the default way to verify a change.
2. Diff two `helm template` outputs, to show what a change actually alters. Diffs are far
   more reviewable than full renders.
3. `helm lint` and other available lint/conformance check tools on rendered output — schema
   and syntax checks.
4. `kubectl --dry-run=server` / `kubectl diff` — only against dev, only when it is up.
5. Applying to dev — last, and only when the render already looks right. Since `tilt` is used
   for local development with the cluster, it is likely that the change was already aplied to
   the cluster. Don't try to apply it manualy, give it some time and only do so if it does not
   appear after 30 seconds if the cluster is fully running. Verification using `kubectl` is
   always allowed if the dev cluster is up.

When verifying a change to a `values.prod.yaml`, render it with `helm template` and
inspect the output. Rendering production values is safe; connecting to production
is not.

## What you can do freely

- Read anything in the repository.
- Write and edit Kubernetes manifests, Helm charts, templates, and `values.dev.yaml`.
- Edit `values.prod.yaml` files.
- Run static validators and renderers: `helm template`, `helm lint`, `kustomize build`, etc.
- Read-only `kubectl` against a running dev cluster.
- Write and update documentation.
- Run `git` read commands. Commit when asked; do not try to push, it requires a password for
  the ssh key.

## Layout

| Path                                                                                                                                             | Contents                                                                                                                           | Agent access                                                        |
| ------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| `deploy/ansible/roles/{service,traefik}`                                                                                                         | Ansible service roles still running prod                                                                                           | read-only, never executed                                           |
| `deploy/ansible/host_vars/prod/`                                                                                                                 | Prod node vars (`*.enc.yaml`, Ansible-Vault-encrypted)                                                                             | read-only, never executed                                           |
| `deploy/ansible/{host_vars/dev,group_vars,inventory,roles/{base,dhcp,firewall,infrastructure,mirror,mount,python,sshd,tailscale,wakeonlan,zfs}}` | Node bootstrap, common roles, dev vars, inventory                                                                                  | editable, never executed                                            |
| `deploy/kubernetes/apps/<name>/`                                                                                                                 | Per-service Helm charts (`Chart.yaml`, `values{,.dev,.prod}.yaml`, `templates/`, `secrets/`); depend on the `common` library chart | editable (`values.prod.yaml` is the only prod-scoped writable file) |
| `deploy/kubernetes/charts/common/`                                                                                                               | Library chart (`type: library`) exposing `_default-ingress.tpl`, `_default-netpol.tpl`, `_default-pvc.tpl`, `_traefik-netpol.tpl`  | editable                                                            |
| `deploy/kubernetes/infrastructure/`                                                                                                              | Cluster-infra Helm charts (currently `storage/`)                                                                                   | editable                                                            |
| `deploy/kubernetes/sops-config.yaml`, `sops-dev-secret-key.enc.age`                                                                              | SOPS config and dev age key                                                                                                        | never access!!                                                      |
| `deploy/kubernetes/sops-prod-secret-key.enc.age`                                                                                                 | Prod age key                                                                                                                       | never access!!                                                      |
| `deploy/argocd/{apps,bootstrap}/`                                                                                                                | Argo CD `Application` manifests and root-app bootstrap                                                                             | editable                                                            |
| `deploy/k3d/cluster.yaml`                                                                                                                        | Local dev cluster (k3d) definition                                                                                                 | editable                                                            |
| `deploy/k3s/config.yaml`                                                                                                                         | k3s server config (disables the built-in traefik)                                                                                  | editable                                                            |
| `deploy/tilt/Tiltfile.bzl`                                                                                                                       | Tilt entrypoint that renders every dev chart                                                                                       | editable                                                            |
| `deploy/vagrant/{charon,daisy}/`                                                                                                                 | Vagrantfiles for local node VMs                                                                                                    | editable                                                            |
| `justfile`, `scripts/`                                                                                                                           | Human-only entrypoints and their helper scripts                                                                                    | never executed                                                      |

## Conventions

- Values file naming: `values.yaml` (defaults), `values.dev.yaml`, `values.prod.yaml`
- Both nodes are converging on **Debian**; their **architectures still differ**. Verify
  that any image referenced has a manifest for the target node's architecture before
  scheduling it there.
- Do not pin images to `latest`.
- Do not add new Ansible-managed services. New services go to Kubernetes.
- Use the same tag and or digest when converting from Ansible to Kubernetes. Do not
  perform any kind of upgrade during the transformation.

## Enforcement

Instructions in this file are requests a model can talk itself out of.

**Self-guard (works everywhere, no harness support needed).** The `justfile` guards
itself by requiring an interactive confirmation that an agent cannot supply:

```
[private]
_human-only:
    @test -t 0 || (echo "just recipes are human-only - see AGENTS.md" >&2; exit 1)

deploy-dev: _human-only
    ...
```

## Reporting

End any change that has side conditions with an explicit follow-up section. Do not bury
these in prose:

```
## Manual follow-up required

- [ ] Prod secret `<name>` must be created in `<location>` with `<shape/what it is for>`.
      Not created by me — production secrets are out of scope for agents.
- [ ] `just <recipe>` should be run by a human to <effect>.
- [ ] Live dev verification skipped: dev cluster was not running.
```

Always state:

- Every production secret that needs to be added or changed, and what it is for.
- Every `just` recipe a human should run.
- Whether verification was static-only, and why.
- Anything you chose not to do because a rule above forbade it.
