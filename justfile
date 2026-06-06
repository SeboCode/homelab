# List available recipes
default:
    @just --list --list-submodules

# Bootstrap all dependencies with mise
bootstrap:
    ./scripts/bootstrap.sh

# Lock a dependency file - target: mise | python | ruby
lock target:
    ./scripts/lock.sh {{ target }}

# Deploy a fresh dev node and provision it - node: charon | daisy
deploy:
    ./scripts/deploy-dev.sh

# Expose dev service to the local network
expose:
    ./scripts/expose-dev.sh

mod cluster "./scripts/cluster.just"
mod provision "./scripts/provision.just"
mod ssh "./scripts/ssh.just"

