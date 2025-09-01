#!/usr/bin/env bash

echo "Starting and configuring ssh-agent to populate ssh private key for later use by Ansible..."
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/homelab

cleanup() {
    echo "Cleaning up ssh-agent and ssh private key..."
    ssh-add -d ~/.ssh/homelab
    eval "$(ssh-agent -k)"
}

trap cleanup EXIT
trap cleanup INT
trap cleanup TERM

ansible-playbook ansible/deploy.yaml \
    --ask-vault-pass \
    --inventory=ansible/inventory/prod.ini \
    --extra-vars="@vars/prod.yaml"

