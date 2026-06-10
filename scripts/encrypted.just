[private]
default:
    @just --list encrypted --list-submodules

mod ansible "./encrypted-ansible.just"
mod sops "./encrypted-sops.just"

