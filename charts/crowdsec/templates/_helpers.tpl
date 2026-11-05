{{/* ---------------------------------------------------------------------------
  Naming and labels
--------------------------------------------------------------------------- */}}

{{- define "crowdsec.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "crowdsec.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Name of a component resource. Usage: include "crowdsec.componentName" (list $ "lapi") */}}
{{- define "crowdsec.componentName" -}}
{{- $ctx := index . 0 -}}
{{- printf "%s-%s" (include "crowdsec.fullname" $ctx | trunc 50 | trimSuffix "-") (index . 1) -}}
{{- end -}}

{{/* Selector labels. Usage: include "crowdsec.selectorLabels" (list $ "lapi") */}}
{{- define "crowdsec.selectorLabels" -}}
{{- $ctx := index . 0 -}}
app.kubernetes.io/name: {{ include "crowdsec.name" $ctx }}
app.kubernetes.io/instance: {{ $ctx.Release.Name }}
app.kubernetes.io/component: {{ index . 1 }}
{{- end -}}

{{/* Common labels. Usage: include "crowdsec.labels" (list $ "lapi") */}}
{{- define "crowdsec.labels" -}}
{{- $ctx := index . 0 -}}
helm.sh/chart: {{ printf "%s-%s" $ctx.Chart.Name $ctx.Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "crowdsec.selectorLabels" . }}
app.kubernetes.io/version: {{ include "crowdsec.imageTag" $ctx | quote }}
app.kubernetes.io/managed-by: {{ $ctx.Release.Service }}
app.kubernetes.io/part-of: crowdsec
{{- with $ctx.Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
  Annotations of a resource: commonAnnotations merged with the resource ones (which win).
  Usage: include "crowdsec.annotations" (dict "ctx" $ "extra" .Values.lapi.annotations)
*/}}
{{- define "crowdsec.annotations" -}}
{{- with (merge (dict) (.extra | default dict) .ctx.Values.commonAnnotations) }}
annotations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "crowdsec.imageTag" -}}
{{- .Values.image.tag | default .Chart.AppVersion -}}
{{- end -}}

{{/*
  Image reference: [registry/]repository:tag[@digest]. `imageRegistry` applies when the image has no registry.
  Usage: include "crowdsec.imageRef" (list $ .Values.image $defaultTag)
*/}}
{{- define "crowdsec.imageRef" -}}
{{- $ctx := index . 0 -}}
{{- $image := index . 1 -}}
{{- $ref := $image.repository -}}
{{- with ($image.registry | default $ctx.Values.imageRegistry) }}
{{- $ref = printf "%s/%s" . $ref -}}
{{- end }}
{{- $ref = printf "%s:%s" $ref ($image.tag | default (index . 2)) -}}
{{- with $image.digest }}
{{- $ref = printf "%s@%s" $ref . -}}
{{- end }}
{{- $ref -}}
{{- end -}}

{{- define "crowdsec.image" -}}
{{- include "crowdsec.imageRef" (list . .Values.image .Chart.AppVersion) -}}
{{- end -}}

{{/* ---------------------------------------------------------------------------
  Shared values
--------------------------------------------------------------------------- */}}

{{- define "crowdsec.authSecretName" -}}
{{- .Values.auth.existingSecret | default (include "crowdsec.componentName" (list . "auth")) -}}
{{- end -}}

{{/*
  Environment variables referenced by the LAPI config.yaml.local, shared by the LAPI container
  and its local-machine init container. LOCAL_API_URL is also written to the cscli credentials.
*/}}
{{- define "crowdsec.lapi.configEnv" -}}
- name: LOCAL_API_URL
  value: {{ printf "%s://localhost:8080" (include "crowdsec.lapiScheme" .) }}
- name: REGISTRATION_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ include "crowdsec.authSecretName" . }}
      key: registrationToken
- name: CS_LAPI_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "crowdsec.authSecretName" . }}
      key: csLapiSecret
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.lapi.database.existingSecret }}
      key: {{ .Values.lapi.database.passwordKey }}
{{- end -}}

{{- define "crowdsec.onlineAPISecretName" -}}
{{- .Values.lapi.onlineAPI.existingSecret | default (include "crowdsec.componentName" (list . "capi-credentials")) -}}
{{- end -}}

{{- define "crowdsec.lapiScheme" -}}
{{- ternary "https" "http" .Values.tls.enabled -}}
{{- end -}}

{{/* URL used by agents and AppSec to reach LAPI */}}
{{- define "crowdsec.lapiURL" -}}
{{- if .Values.lapi.enabled -}}
{{- printf "%s://%s.%s.svc:%v" (include "crowdsec.lapiScheme" .) (include "crowdsec.componentName" (list . "lapi")) .Release.Namespace .Values.lapi.service.port -}}
{{- else -}}
{{- .Values.lapi.externalURL -}}
{{- end -}}
{{- end -}}

{{- define "crowdsec.tlsSecretName" -}}
{{- $ctx := index . 0 -}}
{{- $component := index . 1 -}}
{{- if $ctx.Values.tls.certManager.enabled -}}
{{- include "crowdsec.componentName" (list $ctx (printf "%s-tls" $component)) -}}
{{- else -}}
{{- index $ctx.Values.tls.existingSecrets $component -}}
{{- end -}}
{{- end -}}

{{/* ---------------------------------------------------------------------------
  Component configuration
  Each component gets a single ConfigMap holding config.yaml.local, acquis.yaml
  (log processors only) and the user-provided `files`. Every entry is mounted
  with a subPath under /etc/crowdsec; the image entrypoint populates the rest of
  the directory from /staging without overwriting mounted files.
--------------------------------------------------------------------------- */}}

{{/* ConfigMap key of a user file: paths may contain "/" which keys cannot */}}
{{- define "crowdsec.fileKey" -}}
{{- printf "file.%s" (replace "/" "__" .) -}}
{{- end -}}

{{/* Usage: include "crowdsec.configMapData" (dict "configLocal" $dict "acquisition" $list "files" $files) */}}
{{- define "crowdsec.configMapData" -}}
config.yaml.local: |
  {{- toYaml .configLocal | nindent 2 }}
{{- if hasKey . "acquisition" }}
acquis.yaml: |
  {{- range .acquisition }}
  ---
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end }}
{{- range $path, $content := .files }}
{{ include "crowdsec.fileKey" $path }}: |
  {{- $content | nindent 2 }}
{{- end }}
{{- end -}}

{{/* Usage: include "crowdsec.configVolumeMounts" (dict "acquisition" true "files" $files) */}}
{{- define "crowdsec.configVolumeMounts" -}}
- name: config
  mountPath: /etc/crowdsec/config.yaml.local
  subPath: config.yaml.local
{{- if .acquisition }}
- name: config
  mountPath: /etc/crowdsec/acquis.yaml
  subPath: acquis.yaml
{{- end }}
{{- range $path, $_ := .files }}
- name: config
  mountPath: {{ printf "/etc/crowdsec/%s" $path }}
  subPath: {{ include "crowdsec.fileKey" $path }}
{{- end }}
{{- end -}}

{{/* Hub items installed by the image entrypoint, as environment variables */}}
{{- define "crowdsec.hubEnv" -}}
{{- $envNames := dict "collections" "COLLECTIONS" "parsers" "PARSERS" "scenarios" "SCENARIOS" "postoverflows" "POSTOVERFLOWS" "contexts" "CONTEXTS" "appsecConfigs" "APPSEC_CONFIGS" "appsecRules" "APPSEC_RULES" -}}
{{- range $key, $items := . }}
{{- if $items }}
- name: {{ get $envNames $key }}
  value: {{ join " " $items | quote }}
{{- end }}
{{- end }}
{{- end -}}

{{/* ---------------------------------------------------------------------------
  Pod helpers shared by every component.
  Usage: include "crowdsec.podMetadata" (dict "ctx" $ "component" "lapi" "values" .Values.lapi "checksum" $sum)
--------------------------------------------------------------------------- */}}

{{- define "crowdsec.podMetadata" -}}
labels:
  {{- include "crowdsec.selectorLabels" (list .ctx .component) | nindent 2 }}
  {{- with (merge (dict) .values.podLabels .ctx.Values.podLabels .ctx.Values.commonLabels) }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
annotations:
  checksum/config: {{ .checksum }}
  {{- with (merge (dict) .values.podAnnotations .ctx.Values.podAnnotations) }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end -}}

{{/* Pod-level fields that every component exposes the same way */}}
{{- define "crowdsec.podSpecCommon" -}}
{{- with .ctx.Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .values.serviceAccountName }}
serviceAccountName: {{ . }}
{{- end }}
automountServiceAccountToken: false
{{- with .values.podSecurityContext }}
securityContext:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .values.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .values.topologySpreadConstraints }}
topologySpreadConstraints:
  {{- toYaml . | nindent 2 }}
{{- end }}
enableServiceLinks: false
{{- end -}}

{{/*
  Security context and resources of the chart's helper containers (LAPI wait/registration
  init containers, Central API registration Job, test pods).
  Usage: include "crowdsec.helperContainer" $
*/}}
{{- define "crowdsec.helperContainer" -}}
{{- with .Values.helperContainers.securityContext }}
securityContext:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.helperContainers.resources }}
resources:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{/* Probes, resources and security context of the main container */}}
{{- define "crowdsec.containerCommon" -}}
{{- with .values.resources }}
resources:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .values.securityContext }}
securityContext:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- range $probe := list "livenessProbe" "readinessProbe" "startupProbe" }}
{{- with (get $.values $probe) }}
{{- $probeSpec := deepCopy . }}
{{- if and $.httpsProbes $probeSpec.httpGet }}
{{- $_ := set $probeSpec.httpGet "scheme" "HTTPS" }}
{{- end }}
{{ $probe }}:
  {{- toYaml $probeSpec | nindent 2 }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
  Applies the free-form overrides of a component to its rendered workload manifest:
  `containerSpec` is merged into the main container, `podSpec` into the pod spec and
  `workloadSpec` into the Deployment/DaemonSet spec. Maps are merged, lists and scalars replaced.
  Fields built by the chart (containers, volumes, selector...) are refused in validate.yaml.
  Usage: include "crowdsec.applyOverrides" (dict "manifest" $yaml "values" .Values.lapi)
*/}}
{{- define "crowdsec.applyOverrides" -}}
{{- $doc := .manifest | fromYaml -}}
{{- if hasKey $doc "Error" -}}
{{- fail (printf "internal error, the rendered manifest is not valid YAML: %s" $doc.Error) -}}
{{- end -}}
{{- $pod := $doc.spec.template.spec -}}
{{- $_ := mustMergeOverwrite (index $pod.containers 0) (deepCopy (.values.containerSpec | default dict)) -}}
{{- $_ = mustMergeOverwrite $pod (deepCopy (.values.podSpec | default dict)) -}}
{{- $_ = mustMergeOverwrite $doc.spec (deepCopy (.values.workloadSpec | default dict)) -}}
{{ toYaml $doc }}
{{- end -}}
