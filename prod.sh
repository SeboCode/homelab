#!/usr/bin/env bash

ansible-playbook deploy.yaml -i inventory/prod.ini -e "@vars/prod.yaml"
