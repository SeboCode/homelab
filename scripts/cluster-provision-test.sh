#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
require_command="${dir}/require-command.sh"
kustomize=$(${require_command} kustomize)
yq=$(${require_command} yq)

config_file="${dir}/../.direnv/kubeconfig"
cluster_context="k3d-$(${yq} ".metadata.name" "${dir}/../deploy/k3d/cluster.yaml")"
${kustomize} build "${dir}/../deploy/argocd/bootstrap" | kubectl --kubeconfig "${config_file}" --context "${cluster_context}" apply -f -

