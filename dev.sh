#!/usr/bin/env bash

cd ./platform-stack/deployserver

vagrant destroy -f
vagrant up --provision

