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
      {{- if and .svc.config (hasKey .svc.config "enabled") .svc.config.enabled }}
      annotations:
        checksum/config: {{ toYaml .svc.config.data | sha256sum | quote }}
      {{- end }}
    spec:
      containers:
        - name: {{ .name }}
          image: {{ .svc.image }}
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: {{ .svc.port }}
          {{- if .svc.extraPorts }}
          {{- range .svc.extraPorts }}
            - containerPort: {{ .targetPort | default .port }}
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

          {{- if and .svc.config (hasKey .svc.config "enabled") .svc.config.enabled }}
          volumeMounts:
            - name: config
              mountPath: /etc/config.yaml
              subPath: config.yaml
          {{- end }}

      {{- if and .svc.config (hasKey .svc.config "enabled") .svc.config.enabled }}
      volumes:
        - name: config
          configMap:
            name: {{ include "openexposure.serviceFullname" . }}-config
      {{- end }}
{{- end }}
