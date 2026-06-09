[private]
default:
    @just --list cluster provision --list-submodules

# Execute tilt provisioning command on k3d development cluster
dev tilt-command:
    ./cluster-provision-dev.sh {{ tilt-command }}

# Provision production cluster with current manifest (will be removed once gitops workflow is setup)
prod:
    ./cluster-provision-prod.sh

