# crowdsec

[Crowdsec](https://github.com/crowdsecurity/crowdsec) - the open-source and participative IDS & IPS.

![Version: 0.2.3](https://img.shields.io/badge/Version-0.2.3-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.2.0](https://img.shields.io/badge/AppVersion-1.2.0-informational?style=flat-square)

## Get Repo Info

```
helm repo add crowdsec https://crowdsecurity.github.io/helm-charts
helm repo update
```

## Introduction

Before installing the chart, you might want to look at some [concepts](https://docs.crowdsec.net/docs/concepts) of Crowdsec.
This chart deploys the agent as a [daemonSet](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/) that will read the logs from the nodes, and a pod running the Local API to centralize decisions.

You can find a [blog post/tutorial](https://crowdsec.net/blog/kubernetes-crowdsec-integration/) about deploying Crowdsec in Kubernetes.
Here is a [blog post](https://crowdsec.net/blog/kubernetes-crowdsec-integration/) about Crowdsec in Kubernetes.


## Deploying Crowdsec

Given the following example `crowdsec-values.yaml` :

```yaml
#container_runtime: containerd
agent:
  # Specify which logs we want to process (pods present in the node)
  acquisition:
    # We want to read logs of our nginx ingress controllers from the nginx-ingress namespace.
    # The log file names will match the pod names in the namespace.
    - namespace: nginx-ingress
      podName: nginx-ingress-controller-*
      # Specify the program name for the logs to be correctly parsed
      program: nginx
  # Those are ENV variables
  env:
#   if you are using containerd, add the crowdsecurity/cri-logs parser
#    - name: PARSERS
#      value: "crowdsecurity/cri-logs"
    # As we are running Nginx, we want to install the Nginx collection
    - name: COLLECTIONS
      value: "crowdsecurity/nginx"
lapi:
```

You can deploy Crowdsec like this :

```shell
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
| container_runtime | string | `"docker"` | for raw logs format: json or cri (docker|containerd) |
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


## Next steps 

### Checking behavior

 - Use cscli's [alerts](https://doc.crowdsec.net/docs/cscli/cscli_alerts) and [decisions](https://doc.crowdsec.net/docs/cscli/cscli_decisions) on the LAPI pod to see current and past decisions
 - Use [cscli hub list](https://doc.crowdsec.net/docs/cscli/cscli_hub_list) on the agent pod to see enabled parsers/scenarios etc.

### Find your bouncer

 - Find one of [the main bouncers](https://doc.crowdsec.net/docs/bouncers/intro) or [browse the hub](https://hub.crowdsec.net/browse/#bouncers) to the relevant ones.
 - Use [cscli bouncers add](https://doc.crowdsec.net/docs/cscli/cscli_bouncers_add) on the LAPI pod to generate API keys for your bouncers

### Use the console

 - Checkout https://app.crowdsec.net to register your instance and get the most out of Crowdsec!





