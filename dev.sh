#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

platformstack="${$1:-server}"

cd "./platform-stack/$platformstack"

vagrant destroy -f
vagrant up --no-provision
vagrant provision --provision-with vm-setup
vagrant reload --no-provision
vagrant provision --provision-with ansible

