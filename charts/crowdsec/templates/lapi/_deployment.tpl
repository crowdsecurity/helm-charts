{{/* LAPI Deployment, before the podSpec/containerSpec/workloadSpec overrides (see crowdsec.applyOverrides) */}}
{{- define "crowdsec.lapi.deployment" -}}
{{- $values := .Values.lapi }}
{{- $checksum := include (print $.Template.BasePath "/lapi/configmap.yaml") . | sha256sum }}
{{- $machine := include "crowdsec.componentName" (list . "lapi") }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "crowdsec.componentName" (list . "lapi") }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "crowdsec.labels" (list . "lapi") | nindent 4 }}
  {{- include "crowdsec.annotations" (dict "ctx" . "extra" $values.annotations) | nindent 2 }}
spec:
  replicas: {{ $values.replicas }}
  {{- with $values.strategy }}
  strategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "crowdsec.selectorLabels" (list . "lapi") | nindent 6 }}
  template:
    metadata:
      {{- include "crowdsec.podMetadata" (dict "ctx" . "component" "lapi" "values" $values "checksum" $checksum) | nindent 6 }}
    spec:
      {{- include "crowdsec.podSpecCommon" (dict "ctx" . "values" $values) | trim | nindent 6 }}
      initContainers:
        {{- /*
          All replicas share one local machine, used by cscli in the pod. Its password is derived from
          csLapiSecret, so every replica sets the same one and the entrypoint finds matching credentials
          instead of creating a machine per pod.
        */}}
        - name: local-machine
          image: {{ include "crowdsec.image" . }}
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          command:
            - /bin/bash
            - -c
            - |
              set -eu
              # cscli loads the whole LAPI configuration: add the image defaults next to the mounted
              # files, as the entrypoint does (the hub and credentials are not needed, and not readable)
              for f in /staging/etc/crowdsec/*.yaml; do
                case "${f}" in *_credentials.yaml) continue ;; esac
                cp -n "${f}" /etc/crowdsec/
              done
              umask 077
              password=$(printf 'crowdsec-lapi-machine:%s' "${CS_LAPI_SECRET}" | sha256sum | cut -d' ' -f1)
              cscli machines add "${MACHINE_NAME}" --password "${password}" --force -f /dev/null
              printf 'url: %s\nlogin: %s\npassword: %s\n' "${LOCAL_API_URL}" "${MACHINE_NAME}" "${password}" \
                > /run/crowdsec/local_api_credentials.yaml
          env:
            - name: MACHINE_NAME
              value: {{ $machine }}
            {{- include "crowdsec.lapi.configEnv" . | nindent 12 }}
            {{- with $values.env }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- with $values.envFrom }}
          envFrom:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- include "crowdsec.helperContainer" . | trim | nindent 10 }}
          volumeMounts:
            - name: init-etc
              mountPath: /etc/crowdsec
            {{- include "crowdsec.configVolumeMounts" (dict "files" $values.files) | nindent 12 }}
            - name: run
              mountPath: /run/crowdsec
            {{- /* cscli writes a trace directory there */}}
            - name: data
              mountPath: /var/lib/crowdsec/data
            {{- if $values.onlineAPI.enabled }}
            - name: capi-credentials
              mountPath: /etc/crowdsec-capi
              readOnly: true
            {{- end }}
        {{- with $values.extraInitContainers }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      containers:
        - name: lapi
          image: {{ include "crowdsec.image" . }}
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          env:
            - name: DISABLE_AGENT
              value: "true"
            - name: CUSTOM_HOSTNAME
              value: {{ $machine }}
            {{- include "crowdsec.lapi.configEnv" . | nindent 12 }}
            {{- if $values.onlineAPI.enabled }}
            - name: ENROLL_KEY
              valueFrom:
                secretKeyRef:
                  name: {{ include "crowdsec.authSecretName" . }}
                  key: enrollKey
                  optional: true
            {{- with $values.console.instanceName }}
            - name: ENROLL_INSTANCE_NAME
              value: {{ . | quote }}
            {{- end }}
            {{- with $values.console.tags }}
            - name: ENROLL_TAGS
              value: {{ join " " . | quote }}
            {{- end }}
            {{- else }}
            - name: DISABLE_ONLINE_API
              value: "true"
            {{- end }}
            {{- if .Values.tls.enabled }}
            - name: USE_TLS
              value: "true"
            - name: LAPI_CERT_FILE
              value: /etc/ssl/crowdsec/tls.crt
            - name: LAPI_KEY_FILE
              value: /etc/ssl/crowdsec/tls.key
            - name: CACERT_FILE
              value: /etc/ssl/crowdsec/ca.crt
            - name: AGENTS_ALLOWED_OU
              value: agent-ou
            - name: BOUNCERS_ALLOWED_OU
              value: bouncer-ou
            {{- end }}
            {{- with $values.env }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- with $values.envFrom }}
          envFrom:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          ports:
            - name: lapi
              containerPort: 8080
              protocol: TCP
            - name: metrics
              containerPort: 6060
              protocol: TCP
          {{- include "crowdsec.containerCommon" (dict "values" $values "httpsProbes" .Values.tls.enabled) | trim | nindent 10 }}
          volumeMounts:
            {{- include "crowdsec.configVolumeMounts" (dict "files" $values.files) | nindent 12 }}
            - name: data
              mountPath: /var/lib/crowdsec/data
            - name: run
              mountPath: /run/crowdsec
            {{- if $values.onlineAPI.enabled }}
            - name: capi-credentials
              mountPath: /etc/crowdsec-capi
              readOnly: true
            {{- end }}
            {{- if .Values.tls.enabled }}
            - name: tls
              mountPath: /etc/ssl/crowdsec
              readOnly: true
            {{- end }}
            {{- with $values.extraVolumeMounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
        {{- with $values.extraContainers }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      volumes:
        - name: config
          configMap:
            name: {{ include "crowdsec.componentName" (list . "lapi") }}
        - name: data
          emptyDir: {}
        - name: run
          emptyDir: {}
        - name: init-etc
          emptyDir: {}
        {{- if $values.onlineAPI.enabled }}
        - name: capi-credentials
          secret:
            secretName: {{ include "crowdsec.onlineAPISecretName" . }}
            items:
              - key: online_api_credentials.yaml
                path: online_api_credentials.yaml
        {{- end }}
        {{- if .Values.tls.enabled }}
        - name: tls
          secret:
            secretName: {{ include "crowdsec.tlsSecretName" (list . "lapi") }}
        {{- end }}
        {{- with $values.extraVolumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
{{- end -}}
