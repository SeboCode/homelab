#!/usr/bin/env starlark

def require_tool(tool):
    tool = shlex.quote(tool)
    local(
        command="../../scripts/require-command.sh %s" % tool,
        quiet=True,
        echo_off=True,
    )

def encrypted_manifest(manifest):
    require_tool("sops")
    if not os.getenv("SOPS_AGE_KEY"):
        fail("SOPS_AGE_KEY needs to be set in order to decrypt the manifest!")

    watch_file(manifest)
    return local(
        # SOPS_AGE_KEY is set by the caller and thus will be set in this subshell call.
        ["sops", "-d", manifest],
        quiet=True,
        echo_off=True,
    )

require_tool("kubectl")
require_tool("kustomize")
require_tool("helm")

# -------------------------------------------------------------
# Bootstrap sops secret and namespace for sops-secrets-operator
# -------------------------------------------------------------
k8s_yaml("../kubernetes/apps/sops-secrets-operator/manual/namespace.yaml")
k8s_resource(
    new_name="namespace-awaiting-sops-age-key",
    objects=["sops-age-key:secret"],
    resource_deps=["sops-secrets-operator:namespace"],
)
k8s_yaml(encrypted_manifest("../kubernetes/apps/sops-secrets-operator/manual/age-key-secret.dev.enc.yaml"))

# ---------------------
# sops-secrets-operator
# ---------------------
k8s_yaml(
    helm(
        "../kubernetes/apps/sops-secrets-operator/",
        values=["../kubernetes/apps/sops-secrets-operator/values.yaml"],
    ),
    allow_duplicates=True, # The namespace will be applied again, which is fine.
)
k8s_resource(
    new_name="crd-awaiting-digitalocean-dns-credentials",
    objects=["digitalocean-dns-credentials:sopssecret"],
    # Tilt does not infinitely retry applying the sopssecret manifest definitions.
    # Thus we have to wait until the crd is available, which we can by waiting for the
    # sops-secrets-operator to be ready.
    resource_deps=["chart-sops-secrets-operator"],
)

# ------------
# cert-manager
# ------------
k8s_yaml(
    helm(
        "../kubernetes/apps/cert-manager/",
        values=[
            "../kubernetes/apps/cert-manager/values.yaml",
            "../kubernetes/apps/cert-manager/values.dev.yaml",
        ],
    )
)
k8s_resource(
    new_name="crd-awaiting-digitalocean-dns-letsencrypt-issuer",
    objects=["digitalocean-dns-letsencrypt-issuer:clusterissuer"],
    # Tilt does not infinitely retry applying the cluster issuer manifest definitions.
    # Thus we have to wait until the crd is available, which we can by waiting for the
    # cert-manager-webhook to be ready.
    resource_deps=["chart-cert-manager-webhook"],
)

# -------
# traefik
# -------
k8s_yaml(
    helm(
        "../kubernetes/apps/traefik/",
        values=["../kubernetes/apps/traefik/values.yaml"],
    )
)

# -------
# storage
# -------
k8s_yaml(
    helm(
        "../kubernetes/infrastructure/storage/",
        values=[
            "../kubernetes/infrastructure/storage/values.yaml",
            "../kubernetes/infrastructure/storage/values.dev.yaml",
        ],
    )
)

# --------
# services
# --------
k8s_yaml(
    helm(
        "../kubernetes/apps/immich/",
        values=[
            "../kubernetes/apps/immich/values.yaml",
            "../kubernetes/apps/immich/values.dev.yaml",
        ],
    )
)

