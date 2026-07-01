#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

node="${1:-}"

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
require_command="${dir}/require-command.sh"
ssh_agent=$(${require_command} ssh-agent)
ssh_add=$(${require_command} ssh-add)
ansible_playbook=$(${require_command} ansible-playbook)

case "$node" in
    charon|daisy)
        ;;
    *)
        echo "Error: Invalid or missing node '${node}'. Valid options: charon, daisy" >&2
        exit 1
        ;;
esac

echo "Starting and configuring ssh-agent to populate ssh private key for later use by Ansible..."
eval "$(${ssh_agent} -s)"
${ssh_add} ~/.ssh/homelab-$node

cleanup() {
    echo "Cleaning up ssh-agent and ssh private key..."
    ${ssh_add} -d ~/.ssh/homelab-$node
    eval "$(${ssh_agent} -k)"
}

trap cleanup EXIT
trap cleanup INT
trap cleanup TERM

${ansible_playbook} "$dir/../deploy/ansible/$node.yaml" \
    --ask-vault-pass \
    --inventory="$dir/../deploy/ansible/inventory/$node.enc.ini" \
    --extra-vars="@$dir/../deploy/ansible/host_vars/prod/shared-secrets.enc.yaml" \
    --extra-vars="@$dir/../deploy/ansible/host_vars/prod/$node.enc.yaml"
