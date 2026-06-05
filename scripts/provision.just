[private]
default:
    @just --list provision --list-submodules

# Provision dev node - node: charon | daisy
dev node:
    ./provision-dev.sh {{ node }}

# Provision prod node - node: charon | daisy
prod node:
    ./provision-prod.sh {{ node }}

