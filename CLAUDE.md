# CLAUDE.md

@AGENTS.md

The instructions in `AGENTS.md` are the single source of truth for this repository and
apply in full. This file only adds Claude Code specifics — keep it thin, and put any new
rule in `AGENTS.md` so every harness gets it.

## Reminders that matter most here

- **Never run `just` or its referenced scripts** (human-only) and **never run `ansible*`**.
  Both are blocked by the guard script below; the rules exist in `AGENTS.md` so every harness
  gets them.
- **Check before you `kubectl`.** `kubectl cluster-info` is allowed. If the dev cluster
  is not up, fall back to `helm template` rather than trying to reach anything else.
- **Prod secrets:** never create or edit them; list them under "Manual follow-up" instead.
- **`README.md` is stale** — do not read it or use it as a source of truth.

## Permissions

- `deny`: `Bash(just:*)`, `Bash(ansible:*)`, `Bash(ansible-playbook:*)`,
  `Bash(ansible-galaxy:*)`
- `deny`: writes to the Ansible **service** paths only — the rest of `ansible/` is
  editable. Set the glob once the service directory layout is settled.
- `allow`: `Bash(helm template:*)`, `Bash(helm lint:*)`, `Bash(kubectl cluster-info)`,
  `Bash(kubectl config current-context)`
