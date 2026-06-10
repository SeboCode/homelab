#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

echo "In <prod> environment:"
ls -1 "${dir}/../deploy/ansible/host_vars/prod/"
ls -1 "${dir}/../deploy/ansible/inventory/"
echo ""
echo "In <dev> environment:"
echo "shared-secrets.yaml"
