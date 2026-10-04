# Implementation brief: mediastack

Revision: 2 · Status: APPROVED

## Summary

`mediastack` is a new, five-component media-automation stack, modelled structurally on
`immich` (`deploy/kubernetes/apps/immich/`): one chart, one namespace, one Helm release,
multiple components each with their own Deployment + Service + paired
`connectsTo…`-labelled NetworkPolicy, sharing a single node-pinned PVC the way immich's
server/database/redis/machine-learning all share `immich-storage` via different
`subPath`s. The five components are:

- **Deluge** — BitTorrent client, exposes a web UI that Radarr/Sonarr drive as their
  download client. Plain client, no VPN (see Decisions and Out of scope — a deliberate
  v1 cut, not a gap).
- **Prowlarr** — indexer manager; pushes indexer configuration into Radarr and Sonarr via
  their HTTP APIs.
- **Radarr** — movie library manager; uses Deluge as its download client, writes
  completed movies into a shared library directory.
- **Sonarr** — TV library manager; same shape as Radarr, for TV.
- **Jellyfin** — media server; read-only consumer of the movie/TV library directories
  Radarr/Sonarr populate. No outbound `connectsTo…` label — it only needs shared volume
  read access plus its own ingress. Software transcoding only (no GPU passthrough).

This is explicitly a **new service**, not a port of the existing (partial, untested)
Ansible `mediastack` role at `deploy/ansible/roles/service/mediastack/`. That role was
read only to confirm which container talks to which and what gets shared on disk — its
images, tags and env vars are not carried over. All image/tag/port/env facts below come
from fresh upstream research (Step 2), cited independently.

All open questions from revision 1 are resolved as of this revision (r2) — see
Changelog. Nothing is outstanding.

## Decisions

| Item | Value | Source |
| ---- | ----- | ------ |
| Chart shape | One chart (`deploy/kubernetes/apps/mediastack/`), one namespace `mediastack`, 5 components, each a `Deployment` + `Service` (+ `Ingress` where web-facing) | `immich` precedent |
| Node | `charon` | human (r2, confirming the r1 proposal) |
| Architectures needed | amd64 **and** arm64 — all 5 pinned images below publish both, so node choice does not gate any image | Docker Hub API, per component below |
| Storage | **One shared PVC** via `common.pvc.defaultPersistentVolumeClaim`, `storageClassName: local-host-path`, `accessModes: [ReadWriteOnce]`, split by `subPath` per component/shared-dir | `immich`/`kimai` precedent + reasoning below |
| Storage capacity | `250Gi` | human (r2) |
| Secrets | **None required.** No component in this stack has an upstream-documented env var that carries a password (confirmed per component below); do not create a `secrets/` directory or `secrets.yaml` template, unlike immich/kimai | per-component research below |
| `connectsToDeluge` | needed on Radarr and Sonarr — both use Deluge's web UI (JSON-RPC on 8112) as their configured download client | upstream research, see Radarr/Sonarr sections |
| `connectsToRadarr` | needed on Prowlarr — Prowlarr pushes indexer sync to Radarr via its HTTP API on 7878 | upstream research, see Prowlarr section |
| `connectsToSonarr` | needed on Prowlarr — same flow, against Sonarr's API on 8989 | upstream research, see Prowlarr section |
| Jellyfin connectsTo | **none** — Jellyfin only reads the shared `movies`/`tv` subPaths and serves ingress; it does not call any sibling component's API | task scope, confirmed against upstream docs (no Jellyfin→Radarr/Sonarr/Deluge integration exists at the container level) |
| Subdomains | `jellyfin.homelab.mikemarti.ch`, `radarr.homelab.mikemarti.ch`, `sonarr.homelab.mikemarti.ch`, `prowlarr.homelab.mikemarti.ch`, `deluge.homelab.mikemarti.ch` (prod); `jellyfin.dev.homelab.mikemarti.ch`, `radarr.dev.homelab.mikemarti.ch`, `sonarr.dev.homelab.mikemarti.ch`, `prowlarr.dev.homelab.mikemarti.ch`, `deluge.dev.homelab.mikemarti.ch` (dev) | human (r2) — standard repo naming convention, same shape as `immich`'s `values.dev.yaml`/`values.prod.yaml` host split |
| Deluge VPN | **Out of scope for this implementation.** Plain `linuxserver/deluge`, no VPN sidecar, no kill-switch policy | human (r2) — deliberate v1 scope cut, see Out of scope for the exact rationale and how to revisit it |
| Deluge inbound torrent port (6881) | Stays unexposed, as proposed in r1 | human (r2), confirming r1 default |
| Jellyfin hardware transcoding | Software-only, no `/dev/dri` passthrough, as proposed in r1 | human (r2), confirming r1 default |
| Internet-egress NetworkPolicy | Used as proposed in r1: `0.0.0.0/0` all ports/protocols for Deluge; `0.0.0.0/0:443/tcp` for Radarr, Sonarr, Prowlarr | human (r2), confirming r1 default — see "Egress beyond the cluster" below |
| Shared helpers | `common.pvc.defaultPersistentVolumeClaim` (PVC), `common.netpol.defaultDenyAll` (default-deny-all + allow-dns), `common.netpol.traefik` (per-component ingress NetworkPolicy), `common.netpol.defaultIngress` (per-component Ingress) — all at `deploy/kubernetes/charts/common/templates/` | existing services |
| Resources/probes/securityContext | **None set**, matching immich and kimai — neither existing chart sets `resources`, probes, or `securityContext` on any container. Do not introduce these for mediastack either, for consistency | `immich`, `kimai` templates (no such fields present) |
| PUID/PGID for linuxserver.io images (Radarr, Sonarr, Prowlarr, Deluge) | `PUID=0`, `PGID=0` (run as root) | repo has no `securityContext`/`runAsUser` precedent anywhere (see above); running these images as root avoids a chown mismatch against the root-owned `DirectoryOrCreate` hostPath directories the storage infra chart creates. This is a repo-side default, not an upstream recommendation — upstream's own default is `PUID=1000`/`PGID=1000`, see `docs.linuxserver.io` links below |
| TZ | `Europe/Zurich` | repo-wide convention — every Ansible-managed service in `group_vars/{charon,daisy}.yaml` sets `TZ: Europe/Zurich` |

### Per-component: Deluge

| Item | Value | Source |
| ---- | ----- | ------ |
| Image | `docker.io/linuxserver/deluge:2.2.0` | https://hub.docker.com/r/linuxserver/deluge/tags |
| Digest (multi-arch index) | `sha256:1254a0821a2d8768aba9d1258de381f2633890bf9f44f412eead2744b17a391d` | Docker Hub API: `https://hub.docker.com/v2/repositories/linuxserver/deluge/tags/2.2.0` |
| Architectures | amd64 (`sha256:b2e738890808e1ad4fa9621caee4c8abff6f6f4e467891c73565421fd312c49f`), arm64 (`sha256:07b1ee8e126689065bb86e025855655651c8266d3f449544d51a92910b2c856c`) | same Docker Hub API response |
| Container port | `8112/tcp` (web UI / JSON-RPC, the only port other components or ingress need) | https://docs.linuxserver.io/images/docker-deluge/ |
| Other ports (NOT exposed via ingress) | `6881/tcp` + `6881/udp` (inbound torrent peer traffic — stays unexposed, confirmed r2), `58846/tcp` (deluged daemon, thin-client only — unused here since web UI and daemon run in the same container and talk over localhost) | https://docs.linuxserver.io/images/docker-deluge/ |
| Env vars | `PUID=0`, `PGID=0`, `TZ=Europe/Zurich` (repo defaults, see Decisions). Optional upstream var `DELUGE_LOGLEVEL` not set (defaults to `info`/`warning`) | https://docs.linuxserver.io/images/docker-deluge/ |
| Persistence | `/config` (own config, `subPath: deluge/config`), `/downloads` (shared, `subPath: downloads`) | https://docs.linuxserver.io/images/docker-deluge/ |
| Web UI auth | Deluge's web UI has its own password (default `deluge`, set/changed only through the UI after first boot) — **no env var exists to set or disable it**. This cannot be seeded via a Helm secret; a human (or the implementer, post-deploy) must log in once and set it, then re-enter it into Radarr's and Sonarr's download-client config | https://docs.linuxserver.io/images/docker-deluge/ (no password env documented) |
| VPN | **Explicitly out of scope for this implementation** (human decision, r2). The old Ansible role used `docker.io/binhex/arch-delugevpn` (VPN-wrapped) and later had to add a flag to disable it for testing (commit `d8b575a`) — this brief does not carry that over. See Out of scope for the exact rationale and how a future revision would add it back | `deploy/ansible/roles/service/mediastack/tasks/deluge.yaml` (shape only, not a source of fact); decision itself is human (r2) |

### Per-component: Prowlarr

| Item | Value | Source |
| ---- | ----- | ------ |
| Image | `docker.io/linuxserver/prowlarr:2.6.5` | https://hub.docker.com/r/linuxserver/prowlarr/tags |
| Digest (multi-arch index) | `sha256:f2b26429893d4c4cb71941b7ee50b1bdecd9d5f9f9e02d5410615e9f4f7c8d95` | Docker Hub API: `https://hub.docker.com/v2/repositories/linuxserver/prowlarr/tags/2.6.5` |
| Architectures | amd64 (`sha256:aea78c83f859fcfeff7c8863fffdbda817df7ee05467c94d26800a2e099b01b9`), arm64 (`sha256:7b50747630bd51c47e2530cd282dddca3addff97600ec0ce331ae6d5d6223e40`) | same Docker Hub API response |
| Container port | `9696/tcp` | https://docs.linuxserver.io/images/docker-prowlarr/ |
| Env vars | `PUID=0`, `PGID=0`, `TZ=Europe/Zurich` | https://docs.linuxserver.io/images/docker-prowlarr/ |
| Persistence | `/config` (`subPath: prowlarr/config`) — Prowlarr does **not** mount `downloads`/`movies`/`tv`; it only talks to Radarr/Sonarr over HTTP, it never touches files | https://docs.linuxserver.io/images/docker-prowlarr/ |
| Cross-component auth | Prowlarr's "Applications" feature pushes indexer sync into Radarr/Sonarr using **their** API keys. Radarr and Sonarr each generate their own API key at first boot and store it in their own `/config/config.xml` — there is no env var to pre-seed or read it. Linking Prowlarr → Radarr and Prowlarr → Sonarr requires a human (or implementer, post-deploy) to copy each API key from Radarr's/Sonarr's UI into Prowlarr's Applications settings after first boot | general Prowlarr/Radarr/Sonarr behaviour, confirmed via the upstream docs consulted — flagged under Uncertainties for independent re-check since no single authoritative URL documents this end-to-end |

### Per-component: Radarr

| Item | Value | Source |
| ---- | ----- | ------ |
| Image | `docker.io/linuxserver/radarr:6.4.4` | https://hub.docker.com/r/linuxserver/radarr/tags |
| Digest (multi-arch index) | `sha256:adb6c09d6b729ea5e642c99cea35af72702ef476bf4763f153299ac5db9f0b4f` | Docker Hub API: `https://hub.docker.com/v2/repositories/linuxserver/radarr/tags/6.4.4` |
| Architectures | amd64 (`sha256:31ae4abc0dbf5f89b4d039f305c5b953e24d890b9305ea1b4f005c5f43a32b37`), arm64 (`sha256:f343717db7e1daa1e686edf62b5a69b3e9f1054ed07e1b7003b9a829baa5d0ad`) | same Docker Hub API response |
| Container port | `7878/tcp` | https://docs.linuxserver.io/images/docker-radarr/ |
| Env vars | `PUID=0`, `PGID=0`, `TZ=Europe/Zurich` | https://docs.linuxserver.io/images/docker-radarr/ |
| Persistence | `/config` (`subPath: radarr/config`), `/downloads` (shared, `subPath: downloads`, read-write — Radarr renames/moves completed downloads out of here), `/movies` (shared, `subPath: media/movies`, read-write) | https://docs.linuxserver.io/images/docker-radarr/ |
| Download client (Deluge) | Radarr's Deluge download-client integration talks to Deluge's web UI JSON-RPC endpoint, i.e. port **8112**, not the 58846 daemon port — confirmed via Deluge's own JSON-RPC documentation (the web UI exposes the full core RPC over HTTP, which is what Radarr/Sonarr's "Deluge" client type uses) | https://deluge.readthedocs.io/en/deluge-2.0.4/reference/webapi.html |
| External egress | Needs outbound HTTPS (443) to metadata providers (e.g. TheMovieDB) — see "Egress beyond the cluster" in Decisions below | general Radarr behaviour; flagged under Uncertainties for exact hostnames |

### Per-component: Sonarr

| Item | Value | Source |
| ---- | ----- | ------ |
| Image | `docker.io/linuxserver/sonarr:4.0.20` | https://hub.docker.com/r/linuxserver/sonarr/tags |
| Digest (multi-arch index) | `sha256:f247545d23ba8b233d6604575347e48a623fe6ad75dda02348bf81917f3b5c06` | Docker Hub API: `https://hub.docker.com/v2/repositories/linuxserver/sonarr/tags/4.0.20` |
| Architectures | amd64 (`sha256:b2ce6052dd27ede97749da56958384682f1b2b89c2c78bd0363de9d228b6bcb7`), arm64 (`sha256:8416db4409b57b9eb1b83afca159af11fa4b8d79cbf4a656a2d64cc3f310b1a0`) | same Docker Hub API response |
| Container port | `8989/tcp` | https://docs.linuxserver.io/images/docker-sonarr/ |
| Env vars | `PUID=0`, `PGID=0`, `TZ=Europe/Zurich` | https://docs.linuxserver.io/images/docker-sonarr/ |
| Persistence | `/config` (`subPath: sonarr/config`), `/downloads` (shared, `subPath: downloads`, read-write), `/tv` (shared, `subPath: media/tv`, read-write) | https://docs.linuxserver.io/images/docker-sonarr/ |
| Download client (Deluge) | Same as Radarr — Deluge web UI JSON-RPC on port 8112 | https://deluge.readthedocs.io/en/deluge-2.0.4/reference/webapi.html |
| External egress | Needs outbound HTTPS (443) to metadata providers (e.g. TheTVDB) | general Sonarr behaviour; flagged under Uncertainties |

### Per-component: Jellyfin

| Item | Value | Source |
| ---- | ----- | ------ |
| Image | `docker.io/jellyfin/jellyfin:12.1` | https://hub.docker.com/r/jellyfin/jellyfin/tags |
| Digest (multi-arch index) | `sha256:78d3ea1207d1322471fcac39a614f004f2ccf7e878f95ab2977d752f07e4dd7e` | Docker Hub API: `https://hub.docker.com/v2/repositories/jellyfin/jellyfin/tags/12.1` |
| Architectures | amd64 (`sha256:326be1010b16c92e492f6c7dd6fd105943db84ce723c73183279a1ab357b8f9b`), arm64 (`sha256:690b2dcb8f18f144d1091d728208a36e90cbf84a8811c9275b1e3bd96d52944f`) | same Docker Hub API response |
| Released | 2026-09-15, "stable minor update... 47 fixes" | https://forum.jellyfin.org/t-new-jellyfin-server-web-release-12-1 , https://github.com/jellyfin/jellyfin/releases/tag/v12.1 |
| Container port | `8096/tcp` (HTTP web UI/API) | https://jellyfin.org/docs/general/installation/container/ |
| Not used | `7359/udp` DLNA autodiscovery — requires `--net=host`, not applicable/needed behind Traefik ingress; not exposed | https://jellyfin.org/docs/general/installation/container/ |
| Env vars | None required. (`JELLYFIN_PublishedServerUrl` is optional/only for LAN autodiscovery, not applicable behind an ingress hostname — not set) | https://jellyfin.org/docs/general/installation/container/ |
| Persistence | `/config` (`subPath: jellyfin/config`), `/cache` (`subPath: jellyfin/cache`), `/media/movies` (shared, `subPath: media/movies`, **read-only**), `/media/tv` (shared, `subPath: media/tv`, **read-only**) | https://jellyfin.org/docs/general/installation/container/ |
| Hardware transcoding | **Confirmed out of scope (r2, human decision).** Software transcoding only, no `/dev/dri` passthrough | https://jellyfin.org/docs/general/installation/container/ (describes the feature); decision itself is human (r2) |

### Why a single shared PVC (not per-component PVCs)

`downloads` must be writable by Deluge, Radarr and Sonarr; `movies` by Radarr (write) and
Jellyfin (read); `tv` by Sonarr (write) and Jellyfin (read). A `ReadWriteOnce` PVC
restricts mounting to a **single node**, not a single pod — multiple pods on that same
node can mount it concurrently. Since every mediastack component is pinned to the same
node (`charon`, via the storage infra chart's per-service `nodeAffinity`, see
`deploy/kubernetes/infrastructure/storage/templates/pv.yaml`), one `ReadWriteOnce` PVC
with per-component/per-shared-dir `subPath`s is sufficient and matches the existing
`immich` pattern exactly (one `immich-storage` PVC, `subPath: library` /
`subPath: postgres` / `subPath: redis` / `subPath: machine-learning-cache` for its four
containers). No `ReadWriteMany` storage class exists in this repo
(`deploy/kubernetes/infrastructure/storage/templates/storage-class.yaml` is
`kubernetes.io/no-provisioner`, static-PV-only) and introducing one would be a new,
unjustified capability — reject that option.

### Subpath layout (inside the one `mediastack-storage` PVC)

| subPath | Mounted by | Mode |
| ------- | ---------- | ---- |
| `downloads` | Deluge (`/downloads`), Radarr (`/downloads`), Sonarr (`/downloads`) | read-write, all three |
| `media/movies` | Radarr (`/movies`), Jellyfin (`/media/movies`) | read-write (Radarr), read-only (Jellyfin) |
| `media/tv` | Sonarr (`/tv`), Jellyfin (`/media/tv`) | read-write (Sonarr), read-only (Jellyfin) |
| `deluge/config` | Deluge (`/config`) | read-write |
| `radarr/config` | Radarr (`/config`) | read-write |
| `sonarr/config` | Sonarr (`/config`) | read-write |
| `prowlarr/config` | Prowlarr (`/config`) | read-write |
| `jellyfin/config` | Jellyfin (`/config`) | read-write |
| `jellyfin/cache` | Jellyfin (`/cache`) | read-write |

### Egress beyond the cluster

No existing service in this repo (immich, kimai) needs broad internet egress — the
`common.netpol.defaultDenyAll` helper only opens DNS (UDP/TCP 53 to `kube-system`), and
every other flow is ingress-via-Traefik or internal `connectsTo…`. mediastack breaks that
pattern on purpose (confirmed, r2):

- **Deluge** needs essentially unrestricted outbound TCP+UDP (BitTorrent peers connect on
  arbitrary, peer-chosen ports; trackers are also arbitrary hosts/ports). Policy: egress
  to `0.0.0.0/0`, all ports/protocols.
- **Radarr, Sonarr, Prowlarr** need outbound HTTPS (443) to metadata providers and
  indexer sites (arbitrary hostnames, not enumerable in advance). Policy: egress to
  `0.0.0.0/0` on `443/tcp` only.

This is a repository-first for mediastack's NetworkPolicy conventions — the implementer
adds a dedicated egress-only NetworkPolicy (scoped by a pod label such as
`needsInternetEgress: "true"` or per-component egress rules, implementer's choice of
exact selector shape as long as the scope above is preserved) alongside the existing
`common.netpol.defaultDenyAll` / `common.netpol.traefik` usage. Confirmed acceptable by
the human (r2); no narrower scope was requested.

### Inbound torrent port — not exposed

Deluge normally benefits from an externally-reachable inbound port (6881/tcp+udp) for
better peer connectivity/NAT traversal. Traefik's existing `common.netpol.traefik` +
`common.netpol.defaultIngress` helpers are HTTP(S)-only (`Ingress` resources, routed by
Traefik) — they cannot carry raw TCP/UDP peer traffic. Exposing 6881 would require a
`NodePort` or `hostPort`, a mechanism no other service in this repo uses. **Confirmed
(r2): Deluge runs outbound-only**, with degraded inbound peer connectivity. No
NodePort/hostPort is in scope.

### Ingress

Five components are web-facing and each needs the same treatment as `immich`'s
`server-ingress.yaml`/`server-netpol.yaml` pair (`common.netpol.defaultIngress` +
`common.netpol.traefik`, one `Ingress` + one ingress-only `NetworkPolicy` per component).
TLS via `cert-manager.io/cluster-issuer: digitalocean-dns-letsencrypt-issuer` exactly as
the helper already does — no per-service override needed.

| Component | Container port | Prod host | Dev host |
| --------- | --------------- | --------- | -------- |
| Jellyfin | 8096 | `jellyfin.homelab.mikemarti.ch` | `jellyfin.dev.homelab.mikemarti.ch` |
| Radarr | 7878 | `radarr.homelab.mikemarti.ch` | `radarr.dev.homelab.mikemarti.ch` |
| Sonarr | 8989 | `sonarr.homelab.mikemarti.ch` | `sonarr.dev.homelab.mikemarti.ch` |
| Prowlarr | 9696 | `prowlarr.homelab.mikemarti.ch` | `prowlarr.dev.homelab.mikemarti.ch` |
| Deluge | 8112 | `deluge.homelab.mikemarti.ch` | `deluge.dev.homelab.mikemarti.ch` |

Set each host in `values.prod.yaml` (prod column) and `values.dev.yaml` (dev column) per
component, the same split `immich`/`kimai` use (`server.host` in their respective
`values.{dev,prod}.yaml`) — e.g. `jellyfin.host`, `radarr.host`, `sonarr.host`,
`prowlarr.host`, `deluge.host` keys in this chart's `values.yaml` schema, overridden per
environment.

### ArgoCD and Tilt

- New file `deploy/argocd/apps/mediastack.yaml`, same shape as
  `deploy/argocd/apps/immich.yaml`/`kimai.yaml`: `project: default`, `repoURL:
  https://github.com/SeboCode/homelab.git`, `targetRevision: master`, `path:
  deploy/kubernetes/apps/mediastack`, `helm.valueFiles: [values.yaml, values.dev.yaml]`
  (with the same `# TODO: switch to prod` comment the other two carry), automated
  `prune`+`selfHeal` sync policy.
- New Tilt entry in `deploy/tilt/Tiltfile.bzl`, appended after the `kimai` block, same
  `helm("../kubernetes/apps/mediastack/", values=[...values.yaml, ...values.dev.yaml])`
  shape.
- New entries in `deploy/kubernetes/infrastructure/storage/values.yaml`
  (`services.mediastack.capacity: 250Gi`), `values.dev.yaml`
  (`services.mediastack.node: k3d-homelab-dev-cluster-server-0`, `services.mediastack.path:
  /tmp/service-data/mediastack-storage`), and `values.prod.yaml`
  (`services.mediastack.node: charon`, `services.mediastack.path:
  /service-data/mediastack-storage` — matching immich's prod path convention on the same
  node) — mirroring how immich/kimai are registered there. **This is a file outside
  `deploy/kubernetes/apps/mediastack/` that the implementer must also touch** — call this
  out explicitly since it's easy to miss.

### Environment variables (all components, consolidated)

| Component | Name | Value | Secret? |
| --------- | ---- | ----- | ------- |
| Deluge | `PUID` | `0` | no |
| Deluge | `PGID` | `0` | no |
| Deluge | `TZ` | `Europe/Zurich` | no |
| Prowlarr | `PUID` | `0` | no |
| Prowlarr | `PGID` | `0` | no |
| Prowlarr | `TZ` | `Europe/Zurich` | no |
| Radarr | `PUID` | `0` | no |
| Radarr | `PGID` | `0` | no |
| Radarr | `TZ` | `Europe/Zurich` | no |
| Sonarr | `PUID` | `0` | no |
| Sonarr | `PGID` | `0` | no |
| Sonarr | `TZ` | `Europe/Zurich` | no |
| Jellyfin | — | none required | — |

No secret-carrying env var exists for any of the five components at the versions pinned
above (confirmed per-component in the tables). Do not create `secrets/secret.dev.yaml` /
`secret.prod.enc.yaml` / `templates/secrets.yaml` for this chart.

### Persistence (consolidated)

| Mount path | subPath | Component(s) | Notes |
| ---------- | ------- | ------------- | ----- |
| `/downloads` | `downloads` | Deluge, Radarr, Sonarr | shared, read-write for all three |
| `/movies` | `media/movies` | Radarr (rw) | |
| `/media/movies` | `media/movies` | Jellyfin (ro) | same subPath as Radarr's, different mountPath name (upstream convention per image) |
| `/tv` | `media/tv` | Sonarr (rw) | |
| `/media/tv` | `media/tv` | Jellyfin (ro) | same subPath as Sonarr's |
| `/config` | `deluge/config` | Deluge | |
| `/config` | `prowlarr/config` | Prowlarr | |
| `/config` | `radarr/config` | Radarr | |
| `/config` | `sonarr/config` | Sonarr | |
| `/config` | `jellyfin/config` | Jellyfin | |
| `/cache` | `jellyfin/cache` | Jellyfin | |

PVC: one `mediastack-storage`, `ReadWriteOnce`, `local-host-path`, capacity `250Gi`.

## Open questions

None remaining as of r2 — every open question raised in r1 was answered by the human and
is recorded under Decisions and in the Changelog below.

## Out of scope

- No production secrets are required by this brief (none of the five components have a
  password-carrying env var at the pinned versions).
- DNS records for the five subdomains listed under Ingress above — a human creates them.
- **Deluge VPN wrapping.** Explicitly cut from this implementation (human decision, r2).
  Rationale given: "the complexity is not worth it at the moment, get it running first,
  then make it pretty" — i.e. this is a deliberate v1 scope cut, not a forgotten feature.
  A future revision adding VPN support would need to scope: a VPN-capable image or sidecar
  sharing Deluge's network namespace, a VPN credentials secret, a kill-switch
  NetworkPolicy (so Deluge's traffic is blocked rather than falling back to the plain
  egress path if the VPN drops), and probably reworking the "Egress beyond the cluster"
  policy above (today's broad `0.0.0.0/0` egress for Deluge would need to be scoped to
  only the VPN endpoint instead). None of that is designed here.
- Post-deploy manual linking: Deluge's web UI password (default `deluge`, change via UI)
  must be re-entered into Radarr's and Sonarr's download-client settings; Radarr's and
  Sonarr's self-generated API keys must be copied into Prowlarr's "Applications" settings.
  None of this is Helm/Kubernetes-automatable at the researched versions — it's one-time
  manual setup after first deploy, same category as any other first-run wizard (e.g.
  Jellyfin's own setup wizard).

## Uncertainties

Facts I could not confirm with a single authoritative source, flagged for the verifier
to re-check independently.

- **charon's actual CPU architecture.** Nothing in the repo states it statically (checked
  `deploy/ansible/group_vars/{charon,daisy}.yaml`, `deploy/vagrant/*/Vagrantfile`,
  `deploy/k3d/cluster.yaml`, `deploy/kubernetes/infrastructure/storage/values.*.yaml`).
  Doesn't block implementation — the human confirmed `charon` as the node regardless (r2),
  and every pinned image above is multi-arch (amd64+arm64) so the chart works either way.
- **Prowlarr → Radarr/Sonarr API key hand-off mechanics** — described under
  Per-component: Prowlarr above based on general knowledge of how Prowlarr's
  "Applications" sync works, not from one single doc page. Re-verify against
  `https://docs.linuxserver.io/images/docker-prowlarr/` or the Prowlarr wiki before
  treating the "manual copy-paste" conclusion as final.
- **Radarr/Sonarr's exact outbound metadata-provider hostnames** (e.g. TheMovieDB,
  TheTVDB) — not enumerated; the egress policy above intentionally allows all of
  443/tcp rather than a hostname allowlist, which NetworkPolicy cannot express anyway
  (no FQDN-based policy in this repo's NetworkPolicy helpers).
- **Jellyfin 12.1 tag mutability** — Docker Hub shows `12.1` as a tag distinct from
  `12.1.20260915-010956`, both currently pointing at the same digest
  (`sha256:78d3ea1207d1322471fcac39a614f004f2ccf7e878f95ab2977d752f07e4dd7e`) per
  `https://hub.docker.com/v2/repositories/jellyfin/jellyfin/tags/12.1`. If Jellyfin
  re-pushes a patch under the bare `12.1` tag later (as `linuxserverci` does for some of
  its own minor tags), this digest would go stale; the full build tag
  `12.1.20260915-010956` would not. Pinned the shorter tag to match this repo's existing
  style (`immich` uses `v2.4.1`, `kimai` uses `apache-2.55.0`), not the longer one — flag
  if the verifier disagrees.

## Changelog

- r1: initial
- r2: human confirmed all r1 open questions —
  - Subdomains for all five components set to the standard repo convention
    (`<service>.homelab.mikemarti.ch` prod / `<service>.dev.homelab.mikemarti.ch` dev).
  - Node confirmed as `charon`.
  - PVC capacity set to `250Gi`.
  - Deluge VPN explicitly scoped out for this implementation (not forgotten — recorded
    under Out of scope with rationale and a note on what a future revision would need).
  - Inbound torrent port (6881), Jellyfin software-only transcoding, and the broad
    internet-egress NetworkPolicy scope all confirmed as proposed in r1, no changes.
  All open questions resolved; status moved to APPROVED.
