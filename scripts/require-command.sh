#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

command="${1}"

msg="${command} is required but was not found in PATH"
command -v "${command}" >/dev/null 2>&1 || { echo >&2 "${msg}"; exit 1; }
echo "${command}"

