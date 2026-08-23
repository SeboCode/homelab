{{- define "common.pvc.defaultPersistentVolumeClaim" -}}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  # Convention: PVC name matches the pre-reserved claimRef on the corresponding
  # PV in the storage infrastructure chart (deploy/kubernetes/infrastructure/storage).
  name: {{ .Values.namespace }}-storage
  namespace: {{ .Values.namespace }}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-host-path
  resources:
    requests:
      storage: {{ .Values.storage.capacity }}
{{- end -}}
