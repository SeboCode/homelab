[private]
default:
    @just --list cluster --list-submodules

# Delete an existing and create a new k3d development cluster
create:
    ./cluster-create.sh

# Delete an existing k3d development cluster
delete:
    ./cluster-delete.sh

