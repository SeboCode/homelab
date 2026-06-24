[private]
default:
    @just --list helm --list-submodules

# Pull and unpack helm chart based on chart information provided by the chart-download-info.yaml file. Directly using 
# dependencies in the wrapper chart definition is not an option, as digest pinned dependencies are not yet fully
# supported by helm.
pull chart-name:
    ./helm-pull.sh {{ chart-name }}

