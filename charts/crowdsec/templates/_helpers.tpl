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