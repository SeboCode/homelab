[private]
default:
    @just --list encrypted sops --list-submodules

# Create a sops encrypted file
create env path:
    ./encrypted-sops-create.sh {{ env }} {{ invocation_directory() }}/{{ path }}

# Edit a sops encrypted file
edit env path:
    ./encrypted-sops-edit.sh {{ env }} {{ invocation_directory() }}/{{ path }}

