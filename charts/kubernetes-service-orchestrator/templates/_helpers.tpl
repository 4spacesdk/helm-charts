{{/*
Expand the name of the chart.
*/}}
{{- define "kso.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kso.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "kso.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kso.labels" -}}
helm.sh/chart: {{ include "kso.chart" . }}
{{ include "kso.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kso.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kso.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "kso.serviceAccountName" -}}
{{- default (include "kso.fullname" .) .Values.serviceAccount.name }}
{{- end }}

{{/*
The Secret the passwords and the encryption key are read from: the operator's own when
deployment.existingSecret names one, otherwise the one this chart makes from values.
*/}}
{{- define "kso.credentialsSecretName" -}}
{{- .Values.deployment.existingSecret | default (printf "%s-credentials" (include "kso.fullname" .)) -}}
{{- end }}

{{/*
The environment that comes from that Secret, shared by the deployment and the migration job.

From a Secret rather than as `value:` in the pod spec: anyone allowed to `get` a deployment or
a job could read them there, which is granted far more often than reading secrets, and they
followed into `helm get manifest`, GitOps diffs and backups of the objects.
*/}}
{{- define "kso.credentialsEnv" -}}
- name: DB_PASS
  valueFrom:
    secretKeyRef:
      name: {{ include "kso.credentialsSecretName" . }}
      key: db-pass
- name: ENCRYPTION_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "kso.credentialsSecretName" . }}
      key: encryption-key
{{- if or .Values.deployment.existingSecret .Values.deployment.previousEncryptionKeys }}
- name: ENCRYPTION_PREVIOUS_KEYS
  valueFrom:
    secretKeyRef:
      name: {{ include "kso.credentialsSecretName" . }}
      key: encryption-previous-keys
      optional: true
{{- end }}
{{- end }}

{{/*
Every hostname kso is served on, comma separated: the hosts of each routing that is turned
on, and deployment.config.extraHostnames. kso writes absolute urls with BASE_URL - the first
host - and answers on these as well; any other Host header is not trusted.
*/}}
{{- define "kso.allowedHostnames" -}}
{{- $hosts := list -}}
{{- if .Values.ingress.enabled }}{{ range .Values.ingress.hosts }}{{ $hosts = append $hosts .host }}{{ end }}{{ end -}}
{{- if .Values.istio.enabled }}{{ range .Values.istio.hosts }}{{ $hosts = append $hosts . }}{{ end }}{{ end -}}
{{- if and .Values.contour.enabled .Values.contour.host }}{{ $hosts = append $hosts .Values.contour.host }}{{ end -}}
{{- if .Values.gatewayapi.enabled }}{{ range .Values.gatewayapi.hosts }}{{ $hosts = append $hosts . }}{{ end }}{{ end -}}
{{- range .Values.deployment.config.extraHostnames }}{{ $hosts = append $hosts . }}{{ end -}}
{{- $hosts | uniq | join "," -}}
{{- end }}

{{/*
The origins a browser may open the push connection from: every hostname kso is served on, over
https, space separated as Centrifugo reads them.
*/}}
{{- define "kso.pushAllowedOrigins" -}}
{{- $origins := list -}}
{{- range (splitList "," (include "kso.allowedHostnames" .)) }}{{ if . }}{{ $origins = append $origins (printf "https://%s" .) }}{{ end }}{{ end -}}
{{- $origins | join " " -}}
{{- end }}

{{/*
TLS to the database, from the Secret deployment.database.tls names: where kso finds the
certificates, and the volume they are mounted from. Shared by the deployment and the
migration job.
*/}}
{{- define "kso.databaseTlsEnv" -}}
{{- with .Values.deployment.database.tls }}
{{- if .enabled }}
- name: DB_SSL_CA
  value: /etc/kso/database-tls/ca.crt
{{- if .clientCertificate }}
- name: DB_SSL_CERT
  value: /etc/kso/database-tls/tls.crt
- name: DB_SSL_KEY
  value: /etc/kso/database-tls/tls.key
{{- end }}
- name: DB_SSL_VERIFY
  value: {{ ternary "true" "false" (ne .verifyServerCert false) | quote }}
{{- end }}
{{- end }}
{{- end }}

{{- define "kso.databaseTlsVolumeMount" -}}
{{- if .Values.deployment.database.tls.enabled }}
- name: database-tls
  mountPath: /etc/kso/database-tls
  readOnly: true
{{- end }}
{{- end }}

{{- define "kso.databaseTlsVolume" -}}
{{- with .Values.deployment.database.tls }}
{{- if .enabled }}
- name: database-tls
  secret:
    secretName: {{ required "deployment.database.tls.secretName is required when TLS is enabled" .secretName }}
{{- end }}
{{- end }}
{{- end }}
