[private]
default:
    @just --list encrypted sops --list-submodules

# Edit a sops encrypted file (list possible targets using `just encrypted sops list`)
edit env app:
    ./encrypted-sops-edit.sh {{ env }} {{ app }}

