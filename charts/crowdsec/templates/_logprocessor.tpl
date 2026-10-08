{{/*
  Agents and AppSec are both CrowdSec log processors: they share the same pod,
  only the acquisition, hub items, ports and host log mount differ.
*/}}

{{/*
  Ports of a log processor: its main port if any (AppSec listener), metrics, then `extraPorts`.
  Usage: include "crowdsec.logProcessor.ports" (dict "values" .Values.appsec "mainPort" (dict "name" "appsec" "port" 7422)) | fromYamlArray
*/}}
{{- define "crowdsec.logProcessor.ports" -}}
{{- $ports := list -}}
{{- with .mainPort }}
{{- $ports = append $ports . -}}
{{- end }}
{{- $ports = append $ports (dict "name" "metrics" "port" 6060) -}}
{{- toYaml (concat $ports .values.extraPorts) -}}
{{- end -}}

{{/*
  DaemonSet or Deployment of a log processor.
  Usage: include "crowdsec.logProcessor.workload" (dict "ctx" $ "component" "agent" "values" .Values.agent "ports" $ports "hostLogs" true)
*/}}
{{- define "crowdsec.logProcessor.workload" -}}
{{- $values := .values -}}
apiVersion: apps/v1
kind: {{ $values.kind }}
metadata:
  name: {{ include "crowdsec.componentName" (list .ctx .component) }}
  namespace: {{ .ctx.Release.Namespace }}
  labels:
    {{- include "crowdsec.labels" (list .ctx .component) | nindent 4 }}
  {{- include "crowdsec.annotations" (dict "ctx" .ctx "extra" $values.annotations) | nindent 2 }}
spec:
  {{- with (include "crowdsec.workloadSpecCommon" $values | trim) }}
  {{- . | nindent 2 }}
  {{- end }}
  {{- if eq $values.kind "Deployment" }}
  replicas: {{ $values.replicas }}
  {{- with $values.updateStrategy }}
  strategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- else }}
  {{- with $values.updateStrategy }}
  updateStrategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "crowdsec.selectorLabels" (list .ctx .component) | nindent 6 }}
  template:
    {{- include "crowdsec.logProcessor.podTemplate" . | nindent 4 }}
{{- end -}}

{{/* Usage: include "crowdsec.logProcessor.configLocal" . */}}
{{- define "crowdsec.logProcessor.configLocal" -}}
{{- toYaml (dict "api" (dict "client" (dict "credentials_path" "/run/crowdsec/local_api_credentials.yaml"))) -}}
{{- end -}}

{{/*
  Pod template of a log processor.
  Usage: include "crowdsec.logProcessor.podTemplate" (dict "ctx" $ "component" "agent" "values" .Values.agent "ports" $ports "hostLogs" true)
*/}}
{{- define "crowdsec.logProcessor.podTemplate" -}}
{{- $ctx := .ctx -}}
{{- $values := .values -}}
{{- $checksum := include (print $ctx.Template.BasePath (printf "/%s/configmap.yaml" .component)) $ctx | sha256sum -}}
metadata:
  {{- include "crowdsec.podMetadata" (dict "ctx" $ctx "component" .component "values" $values "checksum" $checksum) | nindent 2 }}
spec:
  {{- include "crowdsec.podSpecCommon" (dict "ctx" $ctx "values" $values) | trim | nindent 2 }}
  initContainers:
    {{- /*
      Waits for LAPI, then (without TLS) registers with the auto-registration token.
      The machine name gets a random suffix: init containers re-run with the same pod
      name after a pod sandbox restart, and LAPI refuses to register an existing machine.
      Stale machines are removed by LAPI (db_config.flush.agents_autodelete).
      With TLS, the client certificate is the identity and only the wait is needed.
    */}}
    - name: {{ ternary "wait-for-lapi" "register" $ctx.Values.tls.enabled }}
      image: {{ include "crowdsec.image" $ctx }}
      imagePullPolicy: {{ $ctx.Values.image.pullPolicy }}
      command:
        - /bin/bash
        - -c
        - |
          set -eu
          {{- if $ctx.Values.tls.enabled }}
          until wget -q -O /dev/null -T 5 --no-check-certificate "${LAPI_URL}/health"; do
            echo "Waiting for LAPI at ${LAPI_URL}"
            sleep 5
          done
          {{- else }}
          until cscli -c /staging/etc/crowdsec/config.yaml lapi register \
              --machine "${POD_NAME}-$(tr -dc a-z0-9 </dev/urandom | head -c 6)" \
              --url "${LAPI_URL}" \
              --token "${REGISTRATION_TOKEN}" \
              --file /run/crowdsec/local_api_credentials.yaml; do
            echo "Registration to ${LAPI_URL} failed, retrying in 5s"
            sleep 5
          done
          {{- end }}
      env:
        - name: LAPI_URL
          value: {{ include "crowdsec.lapiURL" $ctx | quote }}
        {{- if not $ctx.Values.tls.enabled }}
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: REGISTRATION_TOKEN
          valueFrom:
            secretKeyRef:
              name: {{ include "crowdsec.authSecretName" $ctx }}
              key: registrationToken
        {{- end }}
      {{- include "crowdsec.helperContainer" $ctx | trim | nindent 6 }}
      volumeMounts:
        - name: run
          mountPath: /run/crowdsec
        {{- /* cscli writes a trace directory there */}}
        - name: data
          mountPath: /var/lib/crowdsec/data
    {{- with $values.extraInitContainers }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  containers:
    - name: {{ .component }}
      image: {{ include "crowdsec.image" $ctx }}
      imagePullPolicy: {{ $ctx.Values.image.pullPolicy }}
      env:
        - name: DISABLE_LOCAL_API
          value: "true"
        - name: DISABLE_ONLINE_API
          value: "true"
        - name: LOCAL_API_URL
          value: {{ include "crowdsec.lapiURL" $ctx | quote }}
        {{- if $ctx.Values.tls.enabled }}
        - name: USE_TLS
          value: "true"
        - name: CLIENT_CERT_FILE
          value: /etc/ssl/crowdsec/tls.crt
        - name: CLIENT_KEY_FILE
          value: /etc/ssl/crowdsec/tls.key
        - name: CACERT_FILE
          value: /etc/ssl/crowdsec/ca.crt
        {{- end }}
        {{- with (include "crowdsec.hubEnv" $values.hub | trim) }}
        {{- . | nindent 8 }}
        {{- end }}
        {{- with $values.env }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with $values.envFrom }}
      envFrom:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      ports:
        {{- range .ports }}
        - name: {{ .name }}
          containerPort: {{ .port }}
          protocol: {{ .protocol | default "TCP" }}
        {{- end }}
      {{- include "crowdsec.containerCommon" (dict "values" $values) | trim | nindent 6 }}
      volumeMounts:
        {{- include "crowdsec.configVolumeMounts" (dict "acquisition" true "files" $values.files) | nindent 8 }}
        - name: data
          mountPath: /var/lib/crowdsec/data
        - name: run
          mountPath: /run/crowdsec
        {{- if $ctx.Values.tls.enabled }}
        - name: tls
          mountPath: /etc/ssl/crowdsec
          readOnly: true
        {{- end }}
        {{- if .hostLogs }}
        - name: host-logs
          mountPath: /var/log
          readOnly: true
        {{- end }}
        {{- with $values.extraVolumeMounts }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    {{- with $values.extraContainers }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  volumes:
    - name: config
      configMap:
        name: {{ include "crowdsec.componentName" (list $ctx .component) }}
    - name: data
      emptyDir: {}
    - name: run
      emptyDir: {}
    {{- if $ctx.Values.tls.enabled }}
    - name: tls
      secret:
        secretName: {{ include "crowdsec.tlsSecretName" (list $ctx "agent") }}
    {{- end }}
    {{- if .hostLogs }}
    - name: host-logs
      hostPath:
        path: /var/log
    {{- end }}
    {{- with $values.extraVolumes }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
{{- end -}}
