#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

category="$1"
env="$2"
filename="$3"

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
require_command="${dir}/require-command.sh"
ansible_vault=$(${require_command} ansible-vault)

case "${category}" in
    inv)
        ${ansible_vault} edit "${dir}/../deploy/ansible/inventory/${filename}.yaml"
        ;;
    var)
        ${ansible_vault} edit "${dir}/../deploy/ansible/host_vars/${env}/${filename}.ini"
        ;;
    *)
        echo "Error: Invalid or missing category '${category}'. Valid options: inv, vars" >&2
        exit 1
        ;;
esac

