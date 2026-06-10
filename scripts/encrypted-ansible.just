[private]
default:
    @just --list encrypted ansible --list-submodules

# List edit file targets of ansible-vault encrypted files
list:
    ./encrypted-ansible-list.sh

# Edit a ansible-vault encrypted file (list possible targets using `just encrypted ansible list`)
edit env file:
    ./encrypted-ansible-edit.sh {{ env }} {{ file }}


