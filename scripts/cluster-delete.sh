#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
require_command="${dir}/require-command.sh"
k3d=$(${require_command} k3d)

${k3d} cluster delete --config "${dir}/../deploy/k3d/cluster.yaml"

