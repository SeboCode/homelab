#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
require_command="${dir}/require-command.sh"
grep=$(${require_command} grep)
k3d=$(${require_command} k3d)
yq=$(${require_command} yq)

cluster_name=$(yq ".metadata.name" "${dir}/../deploy/k3d/cluster.yaml")
cluster_info=$(${k3d} cluster list | ${grep} "${cluster_name}" 2>/dev/null || true)
if [[ ! -z "${cluster_info}" ]]; then
    "${dir}/cluster-delete.sh"
fi
${k3d} cluster create \
    --config "${dir}/../deploy/k3d/cluster.yaml" \
    --volume "${dir}/../deploy/k3s/config.yaml:/etc/rancher/k3s/config.yaml@server:*"

