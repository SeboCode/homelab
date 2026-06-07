#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

parameter="$1"

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
require_command="${dir}/require-command.sh"
tilt=$(${require_command} tilt)

cluster_name="k3d-$(yq ".metadata.name" "${dir}/../deploy/k3d/cluster.yaml")"
http_port=15000
case "${parameter}" in
    "up")
        ${tilt} up -f "${dir}/../deploy/tilt/Tiltfile.bzl" --stream --context "${cluster_name}" --port ${http_port}
        ;;
    "down")
        ${tilt} down -f "${dir}/../deploy/tilt/Tiltfile.bzl" --delete-namespaces --delete-volumes
        ;;
    "ci")
        ${tilt} ci -f "${dir}/../deploy/tilt/Tiltfile.bzl" --context "${cluster_name}" --port ${http_port}
        ;;
    *)
        echo "Unknown parameter for tilt specified. Terminating..."
        ;;
esac

