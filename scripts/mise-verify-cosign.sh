#!/usr/bin/env bash

set -euo pipefail

binary="$1"
signature="$2"
certificate="$3"
cert_identity="$4"
cert_oidc_issuer="$5"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
curl -fsSL --create-dirs -o "${tmp}/${binary}.sig" "${signature}"
curl -fsSL --create-dirs -o "${tmp}/${binary}.cert" "${certificate}"

cosign verify-blob \
    --certificate "${tmp}/${binary}.cert" \
    --signature "${tmp}/${binary}.sig" \
    --certificate-identity "${cert_identity}" \
    --certificate-oidc-issuer "${cert_oidc_issuer}" \
    "${binary}"

