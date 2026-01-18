#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

platformstack="${1:-server}"

if [[ $platformstack == server ]]; then
    node="charon"
else
    node="daisy"
fi

echo "Starting and configuring ssh-agent to populate ssh private key for later use by Ansible..."
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/homelab-$node

cleanup() {
    echo "Cleaning up ssh-agent and ssh private key..."
    ssh-add -d ~/.ssh/homelab-$node
    eval "$(ssh-agent -k)"
}

trap cleanup EXIT
trap cleanup INT
trap cleanup TERM

ansible-playbook "ansible/$platformstack.yaml" \
    --ask-vault-pass \
    --inventory="ansible/inventory/$platformstack.ini" \
    --extra-vars="@ansible/vars/prod/shared-secrets.yaml" \
    --extra-vars="@ansible/vars/prod/$platformstack.yaml"

