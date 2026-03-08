# List available recipes
default:
    @just --list

# Install Python and Ansible requirements
init:
    ./scripts/init.sh

# Deploy to production node (charon | daisy)
deploy-prod node:
    ./scripts/deploy-prod.sh {{ node }}

# Deploy to dev node (charon | daisy)
deploy-dev node:
    ./scripts/deploy-dev.sh {{ node }}

# ssh into dev vm (charon | daisy)
ssh node:
    ./scripts/ssh.sh {{ node }}

# Provision dev node (charon | daisy)
provision-dev node:
    ./scripts/provision-dev.sh {{ node }}

# Expose service to the local network
expose-local:
    ./scripts/expose-local.sh

