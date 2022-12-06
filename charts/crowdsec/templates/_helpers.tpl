# vim: set ft=gotmpl:
---

{{/*
Generate username if not specified in values
*/}}
{{ define "agent.username" }}
{{- if .Values.secrets.username }}
  {{- .Values.secrets.username -}}
{{- else if (lookup "v1" "Secret" .Release.Namespace "agent-credentials").data }}
  {{- $obj := (lookup "v1" "Secret" .Release.Namespace "agent-credentials").data -}}
  {{- index $obj "username" | b64dec -}}
{{- else -}}
  {{- randAlphaNum 48 -}}
{{- end -}}
{{- end -}}

{{/*
Generate password if not specified in values
*/}}
{{ define "agent.password" }}
{{- if .Values.secrets.password }}
  {{- .Values.secrets.password -}}
{{- else if (lookup "v1" "Secret" .Release.Namespace "agent-credentials").data }}
  {{- $obj := (lookup "v1" "Secret" .Release.Namespace "agent-credentials").data -}}
  {{- index $obj "password" | b64dec -}}
{{- else -}}
  {{- randAlphaNum 48 -}}
{{- end -}}
{{- end -}}

{{/*
  notifications parameters check
*/}}
{{ define "notificationsIsNotEmpty" }}
{{- if .Values.config.notifications }}
{{ range $fileName, $content := .Values.config.notifications }}
{{- if $content }}
true
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
  parsers parameters check
*/}}
{{ define "parsersIsNotEmpty" }}
{{- if or (index .Values.config.parsers "s00-raw") (index .Values.config.parsers "s01-parse") (index .Values.config.parsers "s02-enrich") }}
true
{{- end -}}
{{- end -}}

{{/*
  postoverflows parameters check
*/}}
{{ define "postoverflowsIsNotEmpty" }}
{{- if or (index .Values.config.postoverflows "s00-enrich") (index .Values.config.postoverflows "s01-whitelist") }}
true
{{- end -}}
{{- end -}}

{{/*
  lapi custom config check
*/}}
{{ define "lapiCustomConfigIsNotEmpty" }}
{{- if or (index .Values.config "profiles.yaml") ((include "notificationsIsNotEmpty" .)) }}
true
{{- end -}}
{{- end -}}

{{/*
  agent custom config check
*/}}
{{ define "agentCustomConfigIsNotEmpty" }}
{{- if or (include "parsersIsNotEmpty" .) (.Values.config.scenarios) (.Values.config.postoverflows) }}
true
{{- end -}}
{{- end -}}
