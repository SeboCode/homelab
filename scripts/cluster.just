[private]
default:
    @just --list cluster --list-submodules

# Delete an existing and start a new k3d development cluster
rebuild:
    ./cluster-rebuild.sh

# Delete an existing k3d development cluster
delete:
    ./cluster-delete.sh

