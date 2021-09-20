{{/*
Generate username if not specified in values
*/}}
{{ define "agent.username" }}
{{- if .Values.secrets.username }}
  {{- .Values.secrets.username -}}
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
{{- else -}}
  {{- randAlphaNum 48 -}}
{{- end -}}
{{- end -}}