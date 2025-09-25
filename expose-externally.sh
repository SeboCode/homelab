#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

platformstack="${$1:-server}"

ansible-playbook "ansible/$platformstack/expose-externally.yaml"

