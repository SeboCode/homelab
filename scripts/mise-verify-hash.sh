#!/usr/bin/env bash

set -euo pipefail

hash_algorithm="$1"
tarball_dir="$2"
hash_file_url="$3"

tarball=$(set -- ${tarball_dir}/*; echo "$1")
tarball_name=$(basename ${tarball})

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
hash_file="${tmp}/${tarball_name}.hash"
curl -fsSL --create-dirs -o "${hash_file}" "${hash_file_url}"

echo "$(cat "${hash_file}") ${tarball}" | "${hash_algorithm}" -c --strict --quiet -

