#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

delete_virtual_device_volume() {
    volume="${1}"
    sudo ${virsh} vol-delete --pool default $volume || echo "Ignoring volume deletion error, as the volume simply must not exist before execution."
}

node="${1:-}"

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
require_command="${dir}/require-command.sh"
vagrant=$(${require_command} vagrant)
virsh=$(${require_command} virsh)
cd "$dir/../deploy/vagrant/$node"

case "$node" in
    charon)
        ${vagrant} destroy -f
        delete_virtual_device_volume charon_dev-vdb.qcow2
        delete_virtual_device_volume charon_dev-vdc.qcow2
        ${vagrant} up
        ;;
    daisy)
        ${vagrant} destroy -f
        delete_virtual_device_volume daisy_dev-vdb.qcow2
        ${vagrant} up
        ;;
    *)
        echo "Error: Invalid or missing node '${node}'. Valid options: charon, daisy" >&2
        exit 1
        ;;
esac
