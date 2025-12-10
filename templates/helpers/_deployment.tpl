{{/*
Generic deployment template for NEF services
Parameters:
  - name: service name (e.g., "as-session-with-qos")
  - key: values.yaml key for this service (e.g., "asSessionWithQos")
  - context: root context (.)
  - port: container port (default 8080)
  - metricsPort: prometheus metrics port (default same as port)
  - hasConfig: whether service has configmap (default false)
  - env: list of environment variables (optional)
*/}}
{{- define "openexposure.deployment" -}}
{{- $port := .port | default 8080 -}}
{{- $metricsPort := .metricsPort | default $port -}}
{{- $hasConfig := .hasConfig | default false -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "openexposure.serviceFullname" . }}
  labels:
    {{ include "openexposure.labels" . | nindent 4 }}
spec:
  replicas: {{ index .context.Values.replicas .key | default 1 }}
  selector:
    matchLabels:
      {{ include "openexposure.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{ include "openexposure.selectorLabels" . | nindent 8 }}
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: {{ $metricsPort | quote }}
        prometheus.io/path: "/metrics"
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
      containers:
        - name: {{ .name }}
          image: {{ index .context.Values.images .key }}
          imagePullPolicy: IfNotPresent
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
          ports:
            - containerPort: {{ $port }}
              name: http
              protocol: TCP
          {{- if .env }}
          env:
            {{- toYaml .env | nindent 12 }}
          {{- end }}
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
          {{- if $hasConfig }}
          volumeMounts:
            - name: config
              mountPath: /etc/config.yaml
              subPath: config.yaml
              readOnly: true
          {{- end }}
      {{- if $hasConfig }}
      volumes:
        - name: config
          configMap:
            name: {{ include "openexposure.serviceFullname" . }}-config
      {{- end }}
{{- end }}
