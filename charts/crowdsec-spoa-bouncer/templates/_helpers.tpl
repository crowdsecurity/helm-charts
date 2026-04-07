{{/*
Expand the name of the chart.
*/}}
{{- define "crowdsec-spoa-bouncer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "crowdsec-spoa-bouncer.fullname" -}}
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
{{- define "crowdsec-spoa-bouncer.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "crowdsec-spoa-bouncer.labels" -}}
helm.sh/chart: {{ include "crowdsec-spoa-bouncer.chart" . }}
{{ include "crowdsec-spoa-bouncer.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "crowdsec-spoa-bouncer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "crowdsec-spoa-bouncer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Secret name for the bouncer API key
*/}}
{{- define "crowdsec-spoa-bouncer.secretName" -}}
{{- if .Values.bouncer.existingSecretName }}
{{- .Values.bouncer.existingSecretName }}
{{- else }}
{{- printf "%s-spoa-bouncer-apikey" .Release.Name }}
{{- end }}
{{- end }}

{{/*
Secret key for the bouncer API key
*/}}
{{- define "crowdsec-spoa-bouncer.secretKey" -}}
{{- if .Values.bouncer.existingSecretName -}}
{{- .Values.bouncer.existingSecretKey | default "apiKey" -}}
{{- else -}}
apiKey
{{- end -}}
{{- end }}

{{/*
Generate or retrieve the bouncer API key.
If bouncer.apiKey is provided, use it.
If the Secret already exists (lookup), reuse the existing value (persist across upgrades).
Otherwise, generate a random 32-character key.
*/}}
{{- define "crowdsec-spoa-bouncer.apiKey" -}}
{{- if .Values.bouncer.apiKey }}
{{- .Values.bouncer.apiKey }}
{{- else }}
{{- $secretName := printf "%s-spoa-bouncer-apikey" .Release.Name }}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName }}
{{- if and $existing $existing.data }}
{{- index $existing.data "apiKey" | b64dec }}
{{- else }}
{{- randAlphaNum 32 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
LAPI URL — returns bouncer.lapiUrl if set, otherwise defaults to subchart convention.
*/}}
{{- define "crowdsec-spoa-bouncer.lapiURL" -}}
{{- if .Values.bouncer.lapiUrl }}
{{- .Values.bouncer.lapiUrl }}
{{- else }}
{{- printf "http://%s-service:8080" .Release.Name }}
{{- end }}
{{- end }}

{{/*
LAPI Host — extracts hostname from bouncer.lapiUrl, or defaults to <release>-service.
Strips the scheme, port, and trailing slash/path from the URL.
*/}}
{{- define "crowdsec-spoa-bouncer.lapiHost" -}}
{{- if .Values.bouncer.lapiUrl -}}
{{- $stripped := .Values.bouncer.lapiUrl | trimPrefix "https://" | trimPrefix "http://" | trimSuffix "/" -}}
{{- if contains ":" $stripped -}}
{{- index (splitList ":" $stripped) 0 -}}
{{- else -}}
{{- $stripped -}}
{{- end -}}
{{- else -}}
{{- printf "%s-service" .Release.Name -}}
{{- end -}}
{{- end }}

{{/*
LAPI Port — extracts port from bouncer.lapiUrl, or defaults to 8080.
*/}}
{{- define "crowdsec-spoa-bouncer.lapiPort" -}}
{{- if .Values.bouncer.lapiUrl -}}
{{- $stripped := .Values.bouncer.lapiUrl | trimPrefix "https://" | trimPrefix "http://" | trimSuffix "/" -}}
{{- if contains ":" $stripped -}}
{{- index (splitList ":" $stripped) 1 | trimSuffix "/" -}}
{{- else -}}
8080
{{- end -}}
{{- else -}}
8080
{{- end -}}
{{- end }}

{{/*
Check if bouncer config is non-empty
*/}}
{{- define "crowdsec-spoa-bouncer.hasConfig" -}}
{{- if .Values.bouncer.config }}
{{- if gt (len .Values.bouncer.config) 0 }}
true
{{- end }}
{{- end }}
{{- end }}
