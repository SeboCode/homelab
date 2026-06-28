#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
require_command="${dir}/require-command.sh"
kustomize=$(${require_command} kustomize)
kubectl=$(${require_command} kubectl)
yq=$(${require_command} yq)

config_file="${dir}/../.direnv/kubeconfig"
cluster_context="k3d-$(${yq} ".metadata.name" "${dir}/../deploy/k3d/cluster.yaml")"
${kustomize} build "${dir}/../deploy/argocd/bootstrap/argocd" | kubectl --kubeconfig "${config_file}" --context "${cluster_context}" apply --server-side -f -
${kubectl} wait --for condition=established --timeout=15s crd/applications.argoproj.io
${kubectl} apply -f "${dir}/../deploy/argocd/bootstrap/root-app.yaml" # cannot be applied with the argocd bootstrap due to a race condition of the argocd apiVersion and kind not existing yet

