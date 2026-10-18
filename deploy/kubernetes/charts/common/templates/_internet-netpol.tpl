{{- define "common.netpol.internet" -}}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: internet-netpol-egress
  namespace: {{ .Values.namespace }}
spec:
  podSelector:
    matchLabels:
      connectsToInternet: "true"
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            # Cluster-internal IPs (k3s default pod and service CIDRs, see
            # deploy/k3s/config.yaml). Must be excluded so internet-enabled pods
            # cannot reach other pods directly, which would bypass defaultDenyAll.
            except:
              - 10.42.0.0/16
              - 10.43.0.0/16
{{- end -}}

