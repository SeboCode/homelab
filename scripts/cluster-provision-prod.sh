#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
require_command="${dir}/require-command.sh"
kustomize=$(${require_command} kustomize)
# TODO remove once change to prod cluster as it is no longer needed
yq=$(${require_command} yq)
sops=$(${require_command} sops)
age=$(${require_command} age)

tmp="$(mktemp -d /dev/shm/homelab-kustomize.XXXXXXXXXXXXXXXX)"; trap 'rm -rf "$tmp"' EXIT
cp -r "${dir}/../deploy/kubernetes/." "${tmp}"
sops_key=$(${age} -d "${tmp}/sops-prod-secret-key.enc.age")

for encrypted_secret in $(find "${tmp}/overlays/prod/secrets" -name "*.enc.yaml"); do
    filename=$(basename "${encrypted_secret}" .enc.yaml)
    SOPS_AGE_KEY="${sops_key}" \
        ${sops} --config "${tmp}/sops-config.yaml" -d "${encrypted_secret}" > "${tmp}/overlays/prod/secrets/${filename}.yaml"
done

# TODO change this to the production cluster once fully set up
config_file="${dir}/../.direnv/kubeconfig"
# TODO change this to the production cluster once fully set up
cluster_context="k3d-$(${yq} ".metadata.name" "${dir}/../deploy/k3d/cluster.yaml")"
${kustomize} build "${tmp}/overlays/prod" | kubectl --kubeconfig "${config_file}" --context "${cluster_context}" apply -f -

