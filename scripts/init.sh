#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

pip install -r "$dir/../ansible/requirements.txt"
ansible-galaxy install -r "$dir/../ansible/requirements.yaml"
vagrant plugin install vagrant-libvirt vagrant-mutate vagrant-reload

