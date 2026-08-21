#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

env="$1"
file="$2"

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
require_command="${dir}/require-command.sh"
sops=$(${require_command} sops)
age=$(${require_command} age)
vim=$(${require_command} vim)

sops_key=$(${age} -d "${dir}/../deploy/kubernetes/sops-${env}-secret-key.enc.age")
EDITOR="${vim}" \
    SOPS_AGE_KEY="${sops_key}" \
    ${sops} --config "${dir}/../deploy/kubernetes/sops-config.yaml" "${file}"

