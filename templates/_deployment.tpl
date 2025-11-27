{{- define "openexposure.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "openexposure.serviceFullname" . }}
  labels:
    {{ include "openexposure.labels" . | nindent 4 }}
spec:
  replicas: {{ .svc.replicaCount }}
  selector:
    matchLabels:
      {{ include "openexposure.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{ include "openexposure.selectorLabels" . | nindent 8 }}
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: {{ .svc.prometheusPort | default .svc.port | quote }}
        prometheus.io/path: "/metrics"
        {{- if and .svc.config (hasKey .svc.config "enabled") .svc.config.enabled }}
        checksum/config: {{ toYaml .svc.config.data | sha256sum | quote }}
        {{- end }}
    spec:
      {{- if .svc.podSecurityContext }}
      securityContext:
        {{- toYaml .svc.podSecurityContext | nindent 8 }}
      {{- else if .context.Values.global.defaultPodSecurityContext }}
      securityContext:
        {{- toYaml .context.Values.global.defaultPodSecurityContext | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ .name }}
          image: {{ .svc.image }}
          imagePullPolicy: {{ .svc.imagePullPolicy | default .context.Values.global.imagePullPolicy }}
          {{- if .svc.securityContext }}
          securityContext:
            {{- toYaml .svc.securityContext | nindent 12 }}
          {{- else if .context.Values.global.defaultSecurityContext }}
          securityContext:
            {{- toYaml .context.Values.global.defaultSecurityContext | nindent 12 }}
          {{- end }}
          ports:
            - containerPort: {{ .svc.port }}
              name: http
              protocol: TCP
          {{- if .svc.extraPorts }}
          {{- range .svc.extraPorts }}
            - containerPort: {{ .targetPort | default .port }}
              name: {{ .name }}
              protocol: TCP
          {{- end }}
          {{- end }}

          {{- if .svc.env }}
          env:
            {{- range .svc.env }}
            - name: {{ .name }}
              {{- if hasKey . "value" }}
              value: {{ .value | quote }}
              {{- else if hasKey . "valueFrom" }}
              valueFrom:
{{ toYaml .valueFrom | nindent 16 }}
              {{- else }}
              value: ""
              {{- end }}
            {{- end }}
          {{- end }}

          {{- if or (.svc.resources) (.context.Values.global.defaultResources) }}
          resources:
            {{- if .svc.resources }}
            {{- toYaml .svc.resources | nindent 12 }}
            {{- else }}
            {{- toYaml .context.Values.global.defaultResources | nindent 12 }}
            {{- end }}
          {{- end }}

          {{- if and .svc.config (hasKey .svc.config "enabled") .svc.config.enabled }}
          volumeMounts:
            - name: config
              mountPath: /etc/config.yaml
              subPath: config.yaml
              readOnly: true
          {{- end }}

      {{- if and .svc.config (hasKey .svc.config "enabled") .svc.config.enabled }}
      volumes:
        - name: config
          configMap:
            name: {{ include "openexposure.serviceFullname" . }}-config
      {{- end }}
      {{- with .svc.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
