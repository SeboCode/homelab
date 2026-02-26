#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

platformstack="${1:-}"

case "$platformstack" in
    charon|daisy)
        ansible-playbook "ansible/expose-externally.yaml"
        ;;
    *)
        echo "Error: Invalid or missing platform stack '${platformstack}'. Valid options: charon, daisy" >&2
        exit 1
        ;;
esac
