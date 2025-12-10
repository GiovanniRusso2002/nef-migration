{{/*
Generic service template for NEF services
Parameters:
  - name: service name (e.g., "as-session-with-qos")
  - key: values.yaml key for this service (e.g., "asSessionWithQos")
  - context: root context (.)
  - port: service port (default 8080)
*/}}
{{- define "openexposure.service" -}}
{{- $port := .port | default 8080 -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "openexposure.serviceFullname" . }}
  labels:
    {{ include "openexposure.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  ports:
    - port: {{ $port }}
      targetPort: {{ $port }}
      name: http
  selector:
    {{ include "openexposure.selectorLabels" . | nindent 4 }}
{{- end }}


{{/*
Generic ConfigMap template for NEF services
Parameters:
  - name: service name
  - key: values.yaml key for this service
  - context: root context (.)
  - configData: the config data to include
*/}}
{{- define "openexposure.configmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "openexposure.serviceFullname" (dict "name" .name "context" .context) }}-config
  labels:
    {{ include "openexposure.labels" (dict "name" .name "context" .context) | nindent 4 }}
data:
  config.yaml: |
{{ toYaml .configData | indent 4 }}
{{- end }}

