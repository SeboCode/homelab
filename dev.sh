#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

platformstack="${1:-server}"

source virtualenv.sh

cd "./platform-stack/$platformstack"

vagrant destroy -f
sudo virsh vol-delete --pool default  server_dev-vdb.qcow2
sudo virsh vol-delete --pool default  server_dev-vdc.qcow2
vagrant up --no-provision
vagrant provision --provision-with vm-setup
vagrant reload --no-provision
vagrant provision --provision-with ansible

