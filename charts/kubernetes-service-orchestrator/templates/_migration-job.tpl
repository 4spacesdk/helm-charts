{{/*
The migration job's spec, and its name from it.

A Job's pod template cannot be changed once the Job is there, so an upgrade that changes it -
a value such as database TLS, at the same version - could not patch the old one ("field is
immutable"). The name ends in a hash of the spec instead: the same version and values are the
same Job, and the upgrade leaves it be; changed values are a new Job, and Helm removes the old
one. Running `php spark migrate` again is harmless - it runs only what has not run.

The deployment waits for the Job by this name (wait-for-migration).
*/}}
{{- define "kso.migrationJobSpec" -}}
activeDeadlineSeconds: {{ .Values.migration.activeDeadlineSeconds | default 1800 }}
template:
  metadata:
    labels:
      app: {{ include "kso.fullname" . }}
      role: migration
  spec:
    serviceAccountName: {{ include "kso.serviceAccountName" . }}
    containers:
      - name: {{ .Chart.Name }}
        {{- if .Values.securityContext }}
        securityContext:
          {{- toYaml .Values.securityContext | nindent 10 }}
        {{- end }}
        image: "4spaces/kubernetes-service-orchestrator:{{ .Values.image.tag | default .Chart.AppVersion }}"
        imagePullPolicy: {{ .Values.image.pullPolicy | default "IfNotPresent"  }}
        command:
          - /bin/sh
        args:
          - -c
          - cd /var/www/html/ci4 && php spark migrate
        env:
          - name: ENVIRONMENT
            value: {{ .Values.deployment.environment | default "production" }}
            {{- if .Values.ingress.enabled }}
            {{- if .Values.ingress.hosts }}
            {{- with first .Values.ingress.hosts }}
          - name: BASE_URL
            value: https://{{ .host }}
            {{- end }}
            {{- end }}
            {{- end }}
            {{- if .Values.istio.enabled }}
            {{- if .Values.istio.hosts }}
            {{- with first .Values.istio.hosts }}
          - name: BASE_URL
            value: https://{{ .host }}
            {{- end }}
            {{- end }}
            {{- end }}
            {{- if .Values.contour.enabled }}
            {{- if .Values.contour.host }}
          - name: BASE_URL
            value: https://{{ .Values.contour.host }}
            {{- end }}
            {{- end }}
            {{- if .Values.gatewayapi.enabled }}
            {{- if .Values.gatewayapi.hosts }}
            {{- with first .Values.gatewayapi.hosts }}
          - name: BASE_URL
            value: https://{{ . }}
            {{- end }}
            {{- end }}
            {{- end }}
          - name: DB_HOST
            value: {{ required "Database is required" .Values.deployment.database.host | quote }}
          - name: DB_PORT
            value: {{ required "Database is required" .Values.deployment.database.port | quote }}
          - name: DB_NAME
            value: {{ required "Database is required" .Values.deployment.database.name | quote }}
          - name: DB_USER
            value: {{ required "Database is required" .Values.deployment.database.user | quote }}
          {{- include "kso.credentialsEnv" . | nindent 10 }}
          {{- include "kso.databaseTlsEnv" . | nindent 10 }}
        {{- if .Values.deployment.database.tls.enabled }}
        volumeMounts:
          {{- include "kso.databaseTlsVolumeMount" . | nindent 10 }}
        {{- end }}
    {{- if .Values.deployment.database.tls.enabled }}
    volumes:
      {{- include "kso.databaseTlsVolume" . | nindent 6 }}
    {{- end }}
    restartPolicy: OnFailure
{{- end }}

{{- define "kso.migrationJobName" -}}
{{- $prefix := printf "%s-migration-%s" (include "kso.fullname" .) (.Values.image.tag | default .Chart.AppVersion | replace "." "-") | trunc 54 | trimSuffix "-" -}}
{{- printf "%s-%s" $prefix (include "kso.migrationJobSpec" . | sha256sum | trunc 8) -}}
{{- end }}
