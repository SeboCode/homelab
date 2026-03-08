#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

node="${1:-}"

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

case "$node" in
    charon|daisy)
        cd "$dir/../deployments/local/$node"
        vagrant provision --provision-with=ansible
        ;;
    *)
        echo "Error: Invalid or missing node '${node}'. Valid options: charon, daisy" >&2
        exit 1
        ;;
esac
