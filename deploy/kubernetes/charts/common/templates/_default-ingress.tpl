{{- define "common.netpol.defaultIngress" -}}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .appName }}
  namespace: {{ .Values.namespace }}
  annotations:
    cert-manager.io/cluster-issuer: digitalocean-dns-letsencrypt-issuer
    cert-manager.io/private-key-algorithm: ECDSA
    cert-manager.io/private-key-size: "256"
    {{- range $k, $v := .annotations }}
    {{ $k }}: {{ $v | quote }}
    {{- end }}
spec:
  tls:
    - hosts:
        - {{ .host }}
      {{- /* Derived per Ingress: cert-manager's ingress-shim creates one Certificate per
             TLS secret name, so two Ingresses in a namespace must not share one. */}}
      secretName: tls-secret-{{ .appName }}
  rules:
    - host: {{ .host }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ .appName }}
                port:
                  number: {{ .port }}
{{- end -}}

