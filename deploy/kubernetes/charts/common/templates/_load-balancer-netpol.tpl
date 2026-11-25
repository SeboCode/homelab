{{- define "common.netpol.loadBalancer" -}}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ .svcName }}-load-balancer-netpol-ingress
  namespace: {{ .Values.namespace }}
spec:
  podSelector:
    matchLabels:
      exposedByLoadBalancer: "true"
  policyTypes:
    - Ingress
  ingress:
    # k3s ServiceLB forwards LoadBalancer traffic through its own pods in
    # kube-system, with their pod IP as source.
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              svccontroller.k3s.cattle.io/svcname: {{ .svcName }}
              svccontroller.k3s.cattle.io/svcnamespace: {{ .svcNamespace }}
      ports:
        {{- range $protocol, $port := .ports }}
        - protocol: {{ $protocol }}
          port: {{ $port }}
        {{- end }}
{{- end -}}
