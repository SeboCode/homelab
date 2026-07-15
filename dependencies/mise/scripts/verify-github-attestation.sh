#!/usr/bin/env bash

set -euo pipefail

tarball_dir="$1"
repository="$2"

tarball=$(set -- ${tarball_dir}/*; echo "$1")
tarball_digest="$(sha256sum "$tarball" | cut -d' ' -f1)"

bundle="$(mktemp)"; trap 'rm -f "${bundle}"' EXIT

curl -fsSL \
  "https://api.github.com/repos/${repository}/attestations/sha256:${tarball_digest}" \
  | jq '.attestations[0].bundle' > "${bundle}"

cosign verify-blob-attestation \
  --bundle "${bundle}" \
  --new-bundle-format \
  --certificate-identity-regexp "^https://github.com/${repository}/" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --type slsaprovenance1 \
  "${tarball}"

