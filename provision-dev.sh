#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

platformstack="${1:-server}"

cd "./platform-stack/$platformstack"

vagrant provision --provision-with=ansible

