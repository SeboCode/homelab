#!/usr/bin/env bash

cd ./platform-stack/server

vagrant destroy -f
vagrant up --no-provision
vagrant provision --provision-with vm-setup
vagrant reload --no-provision
vagrant provision --provision-with ansible

