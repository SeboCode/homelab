#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
require_command="${dir}/require-command.sh"
pip=$(${require_command} pip)
ansible-galaxy=$(${require_command} ansible-galaxy)
vagrant=$(${require_command} vagrant)

${pip} install -r "$dir/../ansible/requirements.txt"
${ansible-galaxy} install -r "$dir/../ansible/requirements.yaml"
${vagrant} plugin install vagrant-libvirt vagrant-mutate vagrant-reload

