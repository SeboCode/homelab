[private]
default:
    @just --list encrypted sops --list-submodules

# List edit file targets of sops encrypted files
list:
    ./encrypted-sops-list.sh

# Edit a sops encrypted file (list possible targets using `just encrypted sops list`)
edit env file:
    ./encrypted-sops-edit.sh {{ env }} {{ file }}

