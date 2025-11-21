{{- define "openexposure.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "openexposure.serviceFullname" . }}
  labels:
    {{ include "openexposure.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  ports:
    - port: {{ .svc.port }}
      targetPort: {{ .svc.port }}
      name: http
    {{- if .svc.extraPorts }}
    {{- range .svc.extraPorts }}
    - port: {{ .port }}
      targetPort: {{ .targetPort | default .port }}
      name: {{ .name | default (printf "port-%v" .port) }}
    {{- end }}
    {{- end }}
  selector:
    {{ include "openexposure.selectorLabels" . | nindent 4 }}
{{- end }}

