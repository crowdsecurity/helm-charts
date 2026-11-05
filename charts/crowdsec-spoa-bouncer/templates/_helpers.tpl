{{/*
Expand the name of the chart.
*/}}
{{- define "crowdsec-spoa-bouncer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
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
Create the name of the service account to use
*/}}
{{- define "crowdsec-spoa-bouncer.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "crowdsec-spoa-bouncer.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Check if local config override is provided or hostsDir is enabled
*/}}
{{- define "crowdsec-spoa-bouncer.hasLocalConfig" -}}
{{- if or .Values.config.localConfig .Values.config.hostsDir.enabled }}
true
{{- end }}
{{- end }}

{{/*
Check if hostsDir is enabled
*/}}
{{- define "crowdsec-spoa-bouncer.hasHostsDir" -}}
{{- if and .Values.config.hostsDir.enabled .Values.config.hostsDir.existingSecret }}
true
{{- end }}
{{- end }}
