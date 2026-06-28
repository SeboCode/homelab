#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

env="$1"
app="$2"

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
require_command="${dir}/require-command.sh"
sops=$(${require_command} sops)
age=$(${require_command} age)

sops_key=$(${age} -d "${dir}/../deploy/kubernetes/sops-prod-secret-key.enc.age")
SOPS_AGE_KEY="${sops_key}" \
    ${sops} --config "${dir}/../deploy/kubernetes/sops-config.yaml" edit "${dir}/../deploy/kubernetes/apps/${app}/overlays/${env}/secret.enc.yaml"

