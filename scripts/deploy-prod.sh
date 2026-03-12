#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

node="${1:-}"

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

case "$node" in
    charon|daisy)
        ;;
    *)
        echo "Error: Invalid or missing node '${node}'. Valid options: charon, daisy" >&2
        exit 1
        ;;
esac

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

ansible-playbook "$dir/../ansible/$node.yaml" \
    --ask-vault-pass \
    --inventory="$dir/../ansible/inventory/$node.ini" \
    --extra-vars="@$dir/../ansible/host_vars/prod/shared-secrets.yaml" \
    --extra-vars="@$dir/../ansible/host_vars/prod/$node.yaml"
