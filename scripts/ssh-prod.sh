#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

node="${1:-}"

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
require_command="${dir}/require-command.sh"
ssh=$(${require_command} ssh)

case "$node" in
    charon|daisy)
        ${ssh} homelab-${node}
        ;;
    *)
        echo "Error: Invalid or missing node '${node}'. Valid options: charon, daisy" >&2
        exit 1
        ;;
esac

