{{- define "common.netpol.traefik" -}}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ .appName }}-netpol-ingress
  namespace: {{ .Values.namespace }}
spec:
  podSelector:
    matchLabels:
      app: {{ .appName }}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: traefik
          podSelector:
            matchLabels:
              app.kubernetes.io/name: traefik
      ports:
        - protocol: TCP
          port: {{ .port }}
{{- end -}}

