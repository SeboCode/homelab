#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

echo "In <prod> environment:"
ls -1 "${dir}/../deploy/kubernetes/overlays/prod/secrets/" | grep ".enc.yaml$" || true
echo ""
echo "In <dev> environment:"
ls -1 "${dir}/../deploy/kubernetes/overlays/dev/secrets/" | grep ".enc.yaml$" || true

