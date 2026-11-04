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
{{- /*
  Every pod is one machine: registered by the container command with the token (named after the pod),
  or created by LAPI at login with TLS (<CN>@<pod IP>). It is removed on clean shutdown, and LAPI
  deletes the ones left behind by lost pods (db_config.flush.agents_autodelete).
*/ -}}
{{- define "crowdsec.logProcessor.configLocal" -}}
{{- toYaml (dict "api" (dict "client" (dict
  "credentials_path" "/run/crowdsec/local_api_credentials.yaml"
  "unregister_on_exit" true))) -}}
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
      Waits until LAPI answers on /health, so that the main container does not crash-loop
      while LAPI starts. With TLS, the LAPI certificate is checked against the agent CA.
    */}}
    - name: wait-for-lapi
      image: {{ include "crowdsec.image" $ctx }}
      imagePullPolicy: {{ $ctx.Values.image.pullPolicy }}
      command:
        - /bin/sh
        - -c
        - |
          until wget -q -O /dev/null -T 5 "${URL%/}/health"; do
            echo "Waiting for LAPI at ${URL}"
            sleep 5
          done
      env:
        - name: URL
          value: {{ include "crowdsec.lapiURL" $ctx | quote }}
        {{- if $ctx.Values.tls.enabled }}
        - name: SSL_CERT_FILE
          value: /etc/ssl/crowdsec/ca.crt
        {{- end }}
      {{- if $ctx.Values.tls.enabled }}
      volumeMounts:
        - name: tls
          mountPath: /etc/ssl/crowdsec
          readOnly: true
      {{- end }}
      {{- include "crowdsec.helperContainer" $ctx | trim | nindent 6 }}
    {{- with $values.extraInitContainers }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  containers:
    - name: {{ .component }}
      image: {{ include "crowdsec.image" $ctx }}
      imagePullPolicy: {{ $ctx.Values.image.pullPolicy }}
      {{- if not $ctx.Values.tls.enabled }}
      {{- /*
        Registers the pod with the auto-registration token before the image entrypoint, as one
        machine named after the pod. A clean exit unregisters it, so a restart registers again.
        After a crash the machine still exists: the credentials kept in /run/crowdsec (emptyDir,
        survives container restarts) are still valid and are reused.
      */}}
      command:
        - /bin/bash
        - -c
        - |
          set -eu
          creds=/run/crowdsec/local_api_credentials.yaml
          while :; do
            if out=$(cscli -c /staging/etc/crowdsec/config.yaml lapi register \
                --machine "${POD_NAME}" \
                --url "${LOCAL_API_URL}" \
                --token "${REGISTRATION_TOKEN}" \
                --file "${creds}.new" 2>&1); then
              mv -f "${creds}.new" "${creds}"
              echo "Registered machine ${POD_NAME} to ${LOCAL_API_URL}"
              break
            fi
            case "${out}" in
              *"already exist"*)
                if [ -s "${creds}" ]; then
                  echo "Machine ${POD_NAME} is still registered (previous run did not unregister), reusing its credentials"
                  break
                fi
                echo "Machine ${POD_NAME} exists on LAPI but this pod has no credentials for it: delete it with 'cscli machines delete ${POD_NAME}'"
                ;;
            esac
            echo "${out}"
            echo "Registration to ${LOCAL_API_URL} failed, retrying in 5s"
            sleep 5
          done
          exec /bin/bash /docker_start.sh
      {{- end }}
      env:
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
