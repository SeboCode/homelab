#!/usr/bin/env starlark

def require_tool(tool):
    tool = shlex.quote(tool)
    local(
        command="../../scripts/require-command.sh %s" % (tool),
        quiet=True,
        echo_off=True,
    )


require_tool("kubectl")
require_tool("kustomize")
require_tool("helm")

#k8s_yaml(helm("../kubernetes/apps/cert-manager/"))
k8s_yaml(
    helm(
        "../kubernetes/apps/traefik/",
        values = ["../kubernetes/apps/traefik/values.yaml"],
    )
)
k8s_yaml(kustomize("../kubernetes/apps/immich/overlays/dev/"))

