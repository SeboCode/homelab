#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
require_command="${dir}/require-command.sh"
kustomize=$(${require_command} kustomize)
kubectl=$(${require_command} kubectl)
yq=$(${require_command} yq)
age=$(${require_command} age)

config_file="${dir}/../.direnv/kubeconfig"
cluster_context="k3d-$(${yq} ".metadata.name" "${dir}/../deploy/k3d/cluster.yaml")"

# Load the age key before anything gets applied to the cluster
sops_key=$(${age} -d "${dir}/../deploy/kubernetes/sops-prod-secret-key.enc.age")

# Bootstrap age key secret and namespace for sops-secrets-operator
${kubectl} --kubeconfig "${config_file}" --context "${cluster_context}" apply -f "${dir}/../deploy/kubernetes/apps/sops-secrets-operator/manual/namespace.yaml" 
SOPS_AGE_KEY="${sops_key}" sops -d "${dir}/../deploy/kubernetes/apps/sops-secrets-operator/manual/age-key-secret.dev.enc.yaml" | \
    ${kubectl} --kubeconfig "${config_file}" --context "${cluster_context}" apply -f -

${kustomize} build "${dir}/../deploy/argocd/bootstrap/argocd" | ${kubectl} --kubeconfig "${config_file}" --context "${cluster_context}" apply --server-side -f -
${kubectl} wait --for condition=established --timeout=15s crd/applications.argoproj.io
# cannot be applied with the argocd bootstrap due to a race condition of the argocd application crd not existing yet (hence the wait)
${kubectl} --kubeconfig "${config_file}" --context "${cluster_context}" apply -f "${dir}/../deploy/argocd/bootstrap/root-app.yaml"

