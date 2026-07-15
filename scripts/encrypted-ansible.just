[private]
default:
    @just --list encrypted ansible --list-submodules

# Edit a ansible-vault encrypted file
edit path:
    ./encrypted-ansible-edit.sh {{ invocation_directory() }}/{{ path }}

