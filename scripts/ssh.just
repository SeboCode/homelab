[private]
default:
    @just --list ssh --list-submodules

# ssh into dev node - node: charon | daisy
dev node:
    ./ssh-dev.sh {{ node }}

# ssh into prod node - node: charon | daisy
prod node:
    ./ssh-prod.sh {{ node }}

