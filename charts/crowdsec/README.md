# crowdsec

![Version: 0.2.1](https://img.shields.io/badge/Version-0.2.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.2.0](https://img.shields.io/badge/AppVersion-1.2.0-informational?style=flat-square)

Crowdsec helm chart is an open-source, lightweight agent to detect and respond to bad behaviours.

## Get Repo Info

```
helm repo add crowdsec https://crowdsecurity.github.io/helm-charts
helm repo update
```

## Installing the Chart

Before installing the chart, you need to understand some [concepts](https://docs.crowdsec.net/docs/concepts) of Crowdsec.
So you can configure well the chart and being able to parse logs and detect attacks inside your Kubernetes cluster.

Here is a [blog post](https://crowdsec.net/blog/kubernetes-crowdsec-integration/) about crowdsec in kubernetes.

```
# Create namespace for crowdsec
kubectl create ns crowdsec
# Install helm chart with proper values.yaml config
helm install crowdsec crowdsec/crowdsec -f crowdsec-values.yaml -n crowdsec
```

## Uninstalling the Chart

```
helm delete crowdsec -n crowdsec
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| image.repository | string | `"crowdsecurity/crowdsec"` | docker image repository name |
| image.pullPolicy | string | `"IfNotPresent"` | pullPolicy |
| image.tag | string | `"latest"` | docker image tag |
| secrets.username | string | `""` | agent username (default is generated randomly) |
| secrets.password | string | `""` | agent password (default is generated randomly) |
| lapi.env | list | `[]` | environment variables from crowdsecurity/crowdsec docker image |
| lapi.dashboard.enabled | bool | `false` | Enable Metabase Dashboard (by default disabled) |
| lapi.dashboard.image.repository | string | `"metabase/metabase"` | docker image repository name |
| lapi.dashboard.image.pullPolicy | string | `"IfNotPresent"` | pullPolicy |
| lapi.dashboard.image.tag | string | `"v0.41.5"` | docker image tag |
| lapi.dashboard.assetURL | string | `"https://crowdsec-statics-assets.s3-eu-west-1.amazonaws.com/metabase_sqlite.zip"` | Metabase SQLite static DB containing Dashboards |
| lapi.dashboard.ingress | object | `{"annotations":{"nginx.ingress.kubernetes.io/backend-protocol":"HTTP"},"enabled":false,"host":"","ingressClassName":"nginx"}` | Enable ingress object |
| lapi.resources.limits.memory | string | `"100Mi"` |  |
| lapi.resources.requests.cpu | string | `"150m"` |  |
| lapi.resources.requests.memory | string | `"100Mi"` |  |
| lapi.persistentVolume | object | `{"config":{"accessModes":["ReadWriteOnce"],"enabled":true,"size":"100Mi","storageClassName":""},"data":{"accessModes":["ReadWriteOnce"],"enabled":true,"size":"1Gi","storageClassName":""}}` | Enable persistent volumes |
| lapi.persistentVolume.data | object | `{"accessModes":["ReadWriteOnce"],"enabled":true,"size":"1Gi","storageClassName":""}` | Persistent volume for data folder. Stores e.g. registered bouncer api keys |
| lapi.persistentVolume.config | object | `{"accessModes":["ReadWriteOnce"],"enabled":true,"size":"100Mi","storageClassName":""}` | Persistent volume for config folder. Stores e.g. online api credentials |
| lapi.nodeSelector | object | `{}` | nodeSelector for lapi |
| lapi.tolerations | object | `{}` | tolerations for lapi |
| lapi.metrics | object | `{"enabled":false,"serviceMonitor":{"enabled":false}}` | Enable service monitoring (exposes "metrics" port "6060" for Prometheus) |
| lapi.metrics.serviceMonitor | object | `{"enabled":false}` | See also: https://github.com/prometheus-community/helm-charts/issues/106#issuecomment-700847774 |
| agent.acquisition[0] | object | `{"namespace":"ingress-nginx","podName":"ingress-nginx-controller-*","program":"nginx"}` | Specify each pod you want to process it logs (namespace, podName and program) |
| agent.acquisition[0].podName | string | `"ingress-nginx-controller-*"` | to select pod logs to process |
| agent.acquisition[0].program | string | `"nginx"` | program name related to specific parser you will use (see https://hub.crowdsec.net/author/crowdsecurity/configurations/docker-logs) |
| agent.resources.limits.memory | string | `"100Mi"` |  |
| agent.resources.requests.cpu | string | `"150m"` |  |
| agent.resources.requests.memory | string | `"100Mi"` |  |
| agent.env | list | `[]` | environment variables from crowdsecurity/crowdsec docker image |
| agent.nodeSelector | object | `{}` | nodeSelector for agent |
| agent.tolerations | object | `{}` | tolerations for agent |
| agent.metrics | object | `{"enabled":false,"serviceMonitor":{"enabled":false}}` | Enable service monitoring (exposes "metrics" port "6060" for Prometheus) |
| agent.metrics.serviceMonitor | object | `{"enabled":false}` | See also: https://github.com/prometheus-community/helm-charts/issues/106#issuecomment-700847774 |

