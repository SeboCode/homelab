#!/usr/bin/env bash

ansible-playbook deploy-test.yaml -i inventory/test.ini -e "@vars/test.yaml"
