#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
require_command="${dir}/require-command.sh"
grep=$(${require_command} grep)
k3d=$(${require_command} k3d)

cluster_info=$(${k3d} cluster list | ${grep} homelab-local-cluster 2>/dev/null || true)
if [[ ! -z "${cluster_info}" ]]; then
    "${dir}/delete-cluster.sh"
fi
${k3d} cluster create --config "${dir}/../deploy/k3d/cluster.yaml"

