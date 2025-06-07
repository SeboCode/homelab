#!/usr/bin/env bash

ansible-playbook deploy-prod.yaml -i inventory/prod.ini -e "@vars/prod.yaml"
