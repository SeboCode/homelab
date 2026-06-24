#!/usr/bin/env bash

set -euo pipefail

chart_name="$1"

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
require_command="${dir}/require-command.sh"
yq=$(${require_command} yq)
helm=$(${require_command} helm)
tar=$(${require_command} tar)

chart_dir="${dir}/../deploy/kubernetes/infra/${chart_name}"

if [ ! -d "${chart_dir}" ]; then
    echo "Chart '${chart_name}' does not exist."
    exit 1
fi

chart_dependancy_dir="${chart_dir}/charts"
rm -rf "${chart_dependancy_dir}"
mkdir -p "${chart_dependancy_dir}"

chart_url=$(yq ".chart_url" "${chart_dir}/chart-download-info.yaml")
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
${helm} pull -d "${tmp}" --untar --untardir "${chart_dependancy_dir}" "${chart_url}"

