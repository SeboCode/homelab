#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

ansible-playbook --ask-become-pass "$dir/../ansible/expose.yaml"

