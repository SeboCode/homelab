#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

platformstack="${1:-}"

case "$platformstack" in
    server|pi)
        ansible-playbook "ansible/expose-externally.yaml"
        ;;
    *)
        echo "Error: Invalid or missing platform stack '${platformstack}'. Valid options: server, pi" >&2
        exit 1
        ;;
esac

