#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

delete_vitual_device_volume() {
    volume="${1}"
    sudo virsh vol-delete --pool default $volume || echo "Ignoring volume deletion error, as the volume simply must not exist before execution."
}

platformstack="${1:-server}"

cd "./platform-stack/$platformstack"

vagrant destroy -f
delete_vitual_device_volume server_dev-vdb.qcow2
delete_vitual_device_volume server_dev-vdc.qcow2
vagrant up --no-provision
vagrant provision --provision-with vm-setup
vagrant reload --no-provision
vagrant provision --provision-with ansible

