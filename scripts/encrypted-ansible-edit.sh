#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

file="$1"

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
require_command="${dir}/require-command.sh"
ansible_vault=$(${require_command} ansible-vault)
vim=$(${require_command} vim)

EDITOR="${vim}" \
    ${ansible_vault} edit "${file}"

