#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

cleanup() {
    deactivate
}

trap cleanup EXIT
trap cleanup INT
trap cleanup TERM

