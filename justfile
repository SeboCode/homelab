# List available recipes
default:
    @just --list

# Install Python and Ansible requirements
init:
    ./scripts/init.sh

# Deploy to production node (charon | daisy)
deploy-prod node:
    ./scripts/deploy-prod.sh {{ node }}

# Deploy to a freshly rebuilt dev node (charon | daisy)
deploy-dev node:
    ./scripts/deploy-dev.sh {{ node }}

# ssh into dev vm (charon | daisy)
ssh node:
    ./scripts/ssh.sh {{ node }}

# Provision dev node (charon | daisy)
provision node:
    ./scripts/provision.sh {{ node }}

# Expose dev service to the local network
expose:
    ./scripts/expose.sh

