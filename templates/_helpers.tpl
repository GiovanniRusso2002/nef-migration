{{/*
Return the Base Chart Name
*/}}
{{- define "openexposure.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Return Fully Qualified App Name
*/}}
{{- define "openexposure.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "openexposure.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Return fullname for a specific microservice
*/}}
{{- define "openexposure.serviceFullname" -}}
{{ printf "%s-%s" .context.Release.Name .name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "openexposure.selectorLabels" -}}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
Standard labels
*/}}
{{- define "openexposure.labels" -}}
helm.sh/chart: {{ .context.Chart.Name }}-{{ .context.Chart.Version }}
app.kubernetes.io/version: {{ .context.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: helm
{{ include "openexposure.selectorLabels" (dict "name" .name "context" .context) }}
{{- end }}

{{/*
Generic ConfigMap template
*/}}
{{- define "openexposure.configmap" -}}
{{- if and .svc.config (hasKey .svc.config "enabled") .svc.config.enabled }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "openexposure.serviceFullname" (dict "name" .name "context" .context) }}-config
  labels:
    {{ include "openexposure.labels" (dict "name" .name "context" .context) | nindent 4 }}
data:
  config.yaml: |
{{ tpl (toYaml .svc.config.data) .context | indent 6 }}
{{- end }}
{{- end }}

