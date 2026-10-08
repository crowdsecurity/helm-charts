{{/*
  Resources rendered identically for several components.
  Usage: include "crowdsec.service" (dict "ctx" $ "component" "lapi" "values" .Values.lapi "ports" $ports)
  `ports` is a list of {name, port, protocol}; the targetPort is the container port of the same name.
*/}}
{{- define "crowdsec.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "crowdsec.componentName" (list .ctx .component) }}
  namespace: {{ .ctx.Release.Namespace }}
  labels:
    {{- include "crowdsec.labels" (list .ctx .component) | nindent 4 }}
    {{- with .values.service.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- include "crowdsec.annotations" (dict "ctx" .ctx "extra" .values.service.annotations) | nindent 2 }}
spec:
  type: {{ .values.service.type }}
  {{- with .values.service.internalTrafficPolicy }}
  internalTrafficPolicy: {{ . }}
  {{- end }}
  {{- with .values.service.trafficDistribution }}
  trafficDistribution: {{ . }}
  {{- end }}
  {{- with .values.service.extraSpec }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
  selector:
    {{- include "crowdsec.selectorLabels" (list .ctx .component) | nindent 4 }}
  ports:
    {{- $nodePorts := .values.service.nodePorts }}
    {{- range .ports }}
    - name: {{ .name }}
      port: {{ .port }}
      targetPort: {{ .name }}
      protocol: {{ .protocol | default "TCP" }}
      {{- with (get $nodePorts .name) }}
      nodePort: {{ . }}
      {{- end }}
    {{- end }}
{{- end -}}

{{/* Usage: include "crowdsec.serviceMonitor" (dict "ctx" $ "component" "lapi" "values" .Values.lapi) */}}
{{- define "crowdsec.serviceMonitor" -}}
{{- $sm := .values.metrics.serviceMonitor -}}
{{- if $sm.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "crowdsec.componentName" (list .ctx .component) }}
  namespace: {{ .ctx.Release.Namespace }}
  labels:
    {{- include "crowdsec.labels" (list .ctx .component) | nindent 4 }}
    {{- with $sm.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- include "crowdsec.annotations" (dict "ctx" .ctx) | nindent 2 }}
spec:
  selector:
    matchLabels:
      {{- include "crowdsec.selectorLabels" (list .ctx .component) | nindent 6 }}
  endpoints:
    - port: metrics
      path: /metrics
      {{- with $sm.interval }}
      interval: {{ . }}
      {{- end }}
      {{- with $sm.scrapeTimeout }}
      scrapeTimeout: {{ . }}
      {{- end }}
      {{- with $sm.honorLabels }}
      honorLabels: {{ . }}
      {{- end }}
      {{- /*
        `machine` (the node name) is the label the CrowdSec Grafana dashboards group by.
        User relabelings run after it, so they can override or drop it.
      */}}
      relabelings:
        - action: replace
          sourceLabels: [__meta_kubernetes_pod_node_name]
          targetLabel: machine
        {{- with $sm.relabelings }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with $sm.metricRelabelings }}
      metricRelabelings:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
{{- end -}}

{{/* Usage: include "crowdsec.podDisruptionBudget" (dict "ctx" $ "component" "lapi" "values" .Values.lapi) */}}
{{- define "crowdsec.podDisruptionBudget" -}}
{{- if .values.podDisruptionBudget.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "crowdsec.componentName" (list .ctx .component) }}
  namespace: {{ .ctx.Release.Namespace }}
  labels:
    {{- include "crowdsec.labels" (list .ctx .component) | nindent 4 }}
  {{- include "crowdsec.annotations" (dict "ctx" .ctx) | nindent 2 }}
spec:
  maxUnavailable: {{ .values.podDisruptionBudget.maxUnavailable }}
  selector:
    matchLabels:
      {{- include "crowdsec.selectorLabels" (list .ctx .component) | nindent 6 }}
{{- end }}
{{- end -}}
