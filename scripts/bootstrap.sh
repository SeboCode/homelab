#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
require_command="${dir}/require-command.sh"
mise=$(${require_command} mise)

cd "${dir}/../dependencies/mise/"
${mise} install

