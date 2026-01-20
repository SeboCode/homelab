#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

pip install -r requirements.txt
ansible-galaxy install -r ansible/requirements.yaml

