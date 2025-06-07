#!/usr/bin/env bash

ansible-playbook deploy-dev.yaml -i inventory/dev.ini -e "@vars/dev.yaml"
