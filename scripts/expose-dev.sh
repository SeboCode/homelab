#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
require_command="${dir}/require-command.sh"
ansible-playbook=$(${require_command} ansible-playbook)

${ansible-playbook} --ask-become-pass "$dir/../deploy/ansible/expose.yaml"

