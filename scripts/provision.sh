#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

node="${1:-}"

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
require_command="${dir}/require-command.sh"
vagrant=$(${require_command} vagrant)

case "$node" in
    charon|daisy)
        cd "$dir/../deploy/local/vagrant/$node"
        ${vagrant} provision --provision-with=ansible
        ;;
    *)
        echo "Error: Invalid or missing node '${node}'. Valid options: charon, daisy" >&2
        exit 1
        ;;
esac
