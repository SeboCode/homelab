#!/usr/bin/env starlark

def require_tool(tool):
    tool = shlex.quote(tool)
    local(
        command="../../scripts/require-command.sh %s" % (tool),
        quiet=True,
        echo_off=True,
    )

def helm_encrypted_values(chart, values=[], encrypted_values=[]):
    require_tool("sops")
    if not os.getenv("SOPS_AGE_KEY"):
        fail("SOPS_AGE_KEY needs to be set in order to decrypt the values!")

    watch_file(chart)
    for f in values:
        watch_file(f)
    for f in encrypted_values:
        watch_file(f)

    value_parameters = []
    for f in values:
        value_parameters.append("-f")
        value_parameters.append(f)
    for f in encrypted_values:
        value_parameters.append("-f")
        # SOPS_AGE_KEY is set by the caller and thus will be set in this subshell call.
        value_parameters.append("<(sops --config ../kubernetes/sops-config.yaml -d %s)" % f)

    # The "chart" prefix mimics the default behavior of Tilt's built in helm() rule.
    cmd = ["helm", "template", "chart", chart] + value_parameters
    return local(
        # Called as a bash subcommand in order for process substitution to work properly.
        ["bash", "-c", " ".join(cmd)],
        quiet=True,
        echo_off=True,
    )

require_tool("kubectl")
require_tool("kustomize")
require_tool("helm")

k8s_yaml(
    helm_encrypted_values(
        "../kubernetes/apps/cert-manager/",
        values = [
            "../kubernetes/apps/cert-manager/values.yaml",
            "../kubernetes/apps/cert-manager/values.dev.yaml",
        ],
        encrypted_values = [
            "../kubernetes/apps/cert-manager/values.dev.enc.yaml",
        ],
    )
)

k8s_resource(
    new_name="crd-awaiting-digitalocean-dns-letsencrypt-issuer",
    objects=["digitalocean-dns-letsencrypt-issuer:clusterissuer"],
    # Tilt does not infinitely retry applying the cluster issuer manifest definitions.
    # Thus we have to wait until the crd is available, which we can by waiting for the
    # cert-manager webhook to be ready.
    resource_deps=["chart-cert-manager-webhook"],
)

k8s_yaml(
    helm(
        "../kubernetes/apps/traefik/",
        values = ["../kubernetes/apps/traefik/values.yaml"],
    )
)

k8s_yaml(
    helm(
        "../kubernetes/apps/sops-secrets-operator/",
        values = ["../kubernetes/apps/sops-secrets-operator/values.yaml"],
    )
)

k8s_yaml(kustomize("../kubernetes/apps/immich/overlays/dev/"))

