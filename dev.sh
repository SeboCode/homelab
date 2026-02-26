#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

delete_vitual_device_volume() {
    volume="${1}"
    sudo virsh vol-delete --pool default $volume || echo "Ignoring volume deletion error, as the volume simply must not exist before execution."
}

platformstack="${1:-}"

case "$platformstack" in
    charon)
        cd "./platform-stack/$platformstack"
        vagrant destroy -f
        delete_vitual_device_volume charon_dev-vdb.qcow2
        delete_vitual_device_volume charon_dev-vdc.qcow2
        vagrant up --no-provision
        vagrant provision --provision-with vm-setup
        vagrant reload --no-provision
        vagrant provision --provision-with ansible
        ;;
    daisy)
        cd "./platform-stack/$platformstack"
        vagrant destroy -f
        vagrant up --no-provision
        vagrant provision --provision-with vm-setup
        vagrant reload --no-provision
        vagrant provision --provision-with ansible
        ;;
    *)
        echo "Error: Invalid or missing platform stack '${platformstack}'. Valid options: charon, daisy" >&2
        exit 1
        ;;
esac
