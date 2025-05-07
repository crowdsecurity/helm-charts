{{/*
Generate CS_LAPI_SECRET if not specified in values
*/}}
{{ define "lapi.csLapiSecret" }}
{{- if and (not .Values.lapi.enabled) (not .Values.lapi.secrets.csLapiSecret) }}
  {{- fail "lapi.enabled is false, but no lapi.secrets.csLapiSecret provided" }}
{{- end }}
{{- if .Values.lapi.secrets.csLapiSecret }}
  {{- .Values.lapi.secrets.csLapiSecret -}}
{{- else if (lookup "v1" "Secret" .Release.Namespace "crowdsec-lapi-secrets").data }}
  {{- $obj := (lookup "v1" "Secret" .Release.Namespace "crowdsec-lapi-secrets").data -}}
  {{- index $obj "csLapiSecret" | b64dec -}}
{{- else -}}
  {{- randAscii 64 -}}
{{- end -}}
{{- end -}}

{{/*
Generate registrationToken if not specified in values
*/}}
{{ define "lapi.registrationToken" }}
{{- if and (not .Values.lapi.enabled) (empty .Values.lapi.secrets.registrationToken) }}
  {{- fail "lapi.enabled is false, but no lapi.secrets.registrationToken provided" }}
{{- end }}
{{- if .Values.lapi.secrets.registrationToken }}
  {{- .Values.lapi.secrets.registrationToken -}}
{{- else if (lookup "v1" "Secret" .Release.Namespace "crowdsec-lapi-secrets").data }}
  {{- $obj := (lookup "v1" "Secret" .Release.Namespace "crowdsec-lapi-secrets").data -}}
  {{- index $obj "registrationToken" | b64dec -}}
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
{{- if or (index .Values.config "profiles.yaml") (index .Values.config "config.yaml.local") ((include "notificationsIsNotEmpty" .)) }}
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

{{/*
  Check if DISABLE_ONLINE_API is set in lapi.env and store it in a variable
*/}}
{{ define "IsOnlineAPIDisabled" }}
{{- $IsCAPIDisabled := false -}}
{{- range .Values.lapi.env }}
  {{- if and (eq .name "DISABLE_ONLINE_API") (eq .value "true") }}
    {{- $IsCAPIDisabled = true -}}
  {{- end -}}
{{- end -}}
{{- $IsCAPIDisabled }}
{{- end }}

{{/*
  Provide a default value for StoreCAPICredentialsInSecret. 
  If StoreCAPICredentialsInSecret is not set in the values, and there's no persistency for the LAPI config, defaults to true
*/}}
{{ define "StoreCAPICredentialsInSecret" }}
{{- if .Values.lapi.storeCAPICredentialsInSecret -}}
true
{{- else if (and (not .Values.lapi.storeCAPICredentialsInSecret) (not .Values.lapi.persistentVolume.config.enabled)) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/**
  Provide an external secret for LAPI
*/}}
{{ define "lapi.secretName" }}
{{- if .Values.secrets.externalSecret.name -}}
  {{- .Values.secrets.externalSecret.name -}}
{{- else -}}
crowdsec-lapi-secrets
{{- end -}}
{{- end -}}

{{/**
  Provide a name of the key in secret for csLapiSecret
*/}}
{{ define "lapi.csLapiSecretKey" }}
{{- if and .Values.secrets.externalSecret.name .Values.secrets.externalSecret.csLapiSecretKey -}}
  {{- .Values.secrets.externalSecret.csLapiSecretKey -}}
{{- else -}}
csLapiSecret
{{- end -}}
{{- end -}}

{{/**
  Provide a name of the key in secret for registrationToken
*/}}
{{ define "lapi.registrationTokenKey" }}
{{- if and .Values.secrets.externalSecret.name .Values.secrets.externalSecret.registrationTokenKey -}}
  {{- .Values.secrets.externalSecret.registrationTokenKey -}}
{{- else -}}
registrationToken
{{- end -}}
{{- end -}}