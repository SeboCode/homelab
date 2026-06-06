#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

lock_target="${1:-}"

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
require_command="${dir}/require-command.sh"

case "$lock_target" in
    mise)
        cd "${dir}/../dependencies/mise/"
        mise=$(${require_command} mise)
        MISE_LOCKED=0 ${mise} lock 
        ;;
    python)
        uv=$(${require_command} uv)
        ${uv} pip compile --generate-hashes "${dir}/../dependencies/python/requirements.in" -o "${dir}/../dependencies/python/pylock.toml"
        ;;
    ruby)
        bundle=$(${require_command} bundle)
        ${bundle} lock --add-checksums --update --gemfile "${dir}/../dependencies/ruby/Gemfile"
        ;;
    *)
        echo "Error: Invalid or missing lock target '${lock_target}'. Valid options: mise, python, ruby" >&2
        exit 1
        ;;
esac
