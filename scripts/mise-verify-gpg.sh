#!/usr/bin/env bash

set -euo pipefail

tarball_dir="$1"
gpg_key_url="$2"
signature_url_base="$3"

tarball=$(set -- ${tarball_dir}/*; echo "$1")
tarball_name=$(basename ${tarball})

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
gpg_key_file="${tmp}/key.asc"
signature_file="${tmp}/sig.asc"
curl -fsSL --create-dirs -o "${gpg_key_file}" "${gpg_key_url}"
curl -fsSL --create-dirs -o "${signature_file}" "${signature_url_base}/${tarball_name}.asc"

export GNUPGHOME="${tmp}"
gpg --import "${gpg_key_file}"
gpg --verify "${signature_file}" "${tarball}"

