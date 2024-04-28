# crowdsec

![Version: 0.10.0](https://img.shields.io/badge/Version-0.10.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v1.6.1-2](https://img.shields.io/badge/AppVersion-v1.6.1--2-informational?style=flat-square)

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

## Setup for High Availability

Below a basic configuration for High availability

```
# your-values.yaml

# Configure external DB (https://docs.crowdsec.net/docs/configuration/crowdsec_configuration/#configuration-example)
config:
  config.yaml.local: |
    db_config:
      type:     postgresql
      user:     crowdsec
      password: ${DB_PASSWORD}
      db_name:  crowdsec
      host:     192.168.0.2
      port:     5432
      sslmode:  require

lapi:
  # 2 or more replicas for HA
  replicas: 2
  # You can specify your own CS_LAPI_SECRET, or let the chart generate one. Length must be >= 64
  secrets:
    csLapiSecret: <anyRandomSecret>
  # Specify your external DB password here
  extraSecrets:
    dbPassword: <externalDbPassword>
  persistentVolume:
    # When replicas for LAPI is greater than 1, two options, persistent volumes must be disabled, or in ReadWriteMany mode
    config:
      enabled: false
    # data volume is not required, since SQLite isn't used
    data:
      enabled: false
  # DB Password passed through environment variable
  env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: crowdsec-lapi-secrets
          key: dbPassword
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| container_runtime | string | `"docker"` | for raw logs format: json or cri (docker|containerd) |
| image.repository | string | `"crowdsecurity/crowdsec"` | docker image repository name |
| image.pullPolicy | string | `"IfNotPresent"` | pullPolicy |
| image.pullSecrets | list | `[]` | pullSecrets |
| image.tag | string | `""` | docker image tag |
| podAnnotations | object | `{}` | Annotations to be added to pods |
| podLabels | object | `{}` | Labels to be added to pods |
| config.parsers | object | `{"s00-raw":{},"s01-parse":{},"s02-enrich":{}}` | To better understand stages in parsers, you can take a look at https://docs.crowdsec.net/docs/next/parsers/intro/ |
| config.scenarios | object | `{}` | to better understand how to write a scenario, you can take a look at https://docs.crowdsec.net/docs/next/scenarios/intro |
| config.postoverflows | object | `{"s00-enrich":{},"s01-whitelist":{}}` | to better understand how to write a postoverflow, you can take a look at (https://docs.crowdsec.net/docs/next/whitelist/create/#whitelist-in-postoverflows) |
| config."simulation.yaml" | string | `""` | Simulation configuration (https://docs.crowdsec.net/docs/next/scenarios/simulation/) |
| config."console.yaml" | string | `""` |  |
| config."capi_whitelists.yaml" | string | `""` |  |
| config."profiles.yaml" | string | `""` | Profiles configuration (https://docs.crowdsec.net/docs/next/profiles/format/#profile-configuration-example) |
| config."config.yaml.local" | string | `""` | General configuration (https://docs.crowdsec.net/docs/configuration/crowdsec_configuration/#configuration-example) |
| config.notifications | object | `{}` | notifications configuration (https://docs.crowdsec.net/docs/next/notification_plugins/intro) |
| tls.enabled | bool | `false` |  |
| tls.caBundle | bool | `true` |  |
| tls.insecureSkipVerify | bool | `false` |  |
| tls.certManager.enabled | bool | `true` |  |
| tls.certManager.issuerRef | object | `{}` | Use existing issuer to sign certificates. Leave empty to generate a self-signed issuer |
| tls.bouncer.secret | string | `"{{ .Release.Name }}-bouncer-tls"` |  |
| tls.bouncer.reflector.namespaces | list | `[]` |  |
| tls.agent.tlsClientAuth | bool | `true` |  |
| tls.agent.secret | string | `"{{ .Release.Name }}-agent-tls"` |  |
| tls.agent.reflector.namespaces | list | `[]` |  |
| tls.lapi.secret | string | `"{{ .Release.Name }}-lapi-tls"` |  |
| secrets.username | string | `""` | agent username (default is generated randomly) |
| secrets.password | string | `""` | agent password (default is generated randomly) |
| securityContext.runAsUser | string | `"10000"` | User under which certain container are run |
| securityContext.runAsGroup | string | `"10000"` | Group under which certain container are run |
| securityContext.fsgroup | string | `"10000"` | Group applied to files and directories saved on volumes |
| lapi.replicas | int | `1` | replicas for local API |
| lapi.env | list | `[]` | environment variables from crowdsecurity/crowdsec docker image |
| lapi.envFrom | list | `[]` |  |
| lapi.ingress | object | `{"annotations":{"nginx.ingress.kubernetes.io/backend-protocol":"HTTP"},"enabled":false,"host":"","ingressClassName":""}` | Enable ingress lapi object |
| lapi.priorityClassName | string | `""` | pod priority class name |
| lapi.podAnnotations | object | `{}` | Annotations to be added to lapi pods, if global podAnnotations are not set |
| lapi.podLabels | object | `{}` | Labels to be added to lapi pods, if global podLabels are not set |
| lapi.dashboard.enabled | bool | `false` | Enable Metabase Dashboard (by default disabled) |
| lapi.dashboard.env | list | `[]` | see https://www.metabase.com/docs/latest/configuring-metabase/environment-variables |
| lapi.dashboard.image.repository | string | `"metabase/metabase"` | docker image repository name |
| lapi.dashboard.image.pullPolicy | string | `"IfNotPresent"` | pullPolicy |
| lapi.dashboard.image.tag | string | `"v0.46.6.1"` | docker image tag |
| lapi.dashboard.assetURL | string | `"https://crowdsec-statics-assets.s3-eu-west-1.amazonaws.com/metabase_sqlite.zip"` | Metabase SQLite static DB containing Dashboards |
| lapi.dashboard.resources | object | `{}` |  |
| lapi.dashboard.ingress | object | `{"annotations":{"nginx.ingress.kubernetes.io/backend-protocol":"HTTP"},"enabled":false,"host":"","ingressClassName":""}` | Enable ingress object |
| lapi.dashboard.resources.limits.memory | string | `{}` |  |
| lapi.dashboard.resources.requests.cpu | string | `{}` |  |
| lapi.dashboard.resources.requests.memory | string | `{}` |  |
| lapi.resources.limits.memory | string | `"100Mi"` |  |
| lapi.resources.requests.cpu | string | `"150m"` |  |
| lapi.resources.requests.memory | string | `"100Mi"` |  |
| lapi.persistentVolume | object | `{"config":{"accessModes":["ReadWriteOnce"],"enabled":true,"existingClaim":"","size":"100Mi","storageClassName":""},"data":{"accessModes":["ReadWriteOnce"],"enabled":true,"existingClaim":"","size":"1Gi","storageClassName":""}}` | Enable persistent volumes |
| lapi.persistentVolume.data | object | `{"accessModes":["ReadWriteOnce"],"enabled":true,"existingClaim":"","size":"1Gi","storageClassName":""}` | Persistent volume for data folder. Stores e.g. registered bouncer api keys |
| lapi.persistentVolume.config | object | `{"accessModes":["ReadWriteOnce"],"enabled":true,"existingClaim":"","size":"100Mi","storageClassName":""}` | Persistent volume for config folder. Stores e.g. online api credentials |
| lapi.service.type | string | `"ClusterIP"` |  |
| lapi.service.labels | object | `{}` |  |
| lapi.service.annotations | object | `{}` |  |
| lapi.service.externalIPs | list | `[]` |  |
| lapi.service.loadBalancerIP | string | `nil` |  |
| lapi.service.loadBalancerClass | string | `nil` |  |
| lapi.service.externalTrafficPolicy | string | `"Cluster"` |  |
| lapi.nodeSelector | object | `{}` | nodeSelector for lapi |
| lapi.tolerations | list | `[]` | tolerations for lapi |
| lapi.dnsConfig | object | `{}` | dnsConfig for lapi |
| lapi.affinity | object | `{}` | affinity for lapi |
| lapi.topologySpreadConstraints | list | `[]` | topologySpreadConstraints for lapi |
| lapi.metrics | object | `{"enabled":false,"serviceMonitor":{"enabled":false}}` | Enable service monitoring (exposes "metrics" port "6060" for Prometheus) |
| lapi.metrics.serviceMonitor | object | `{"enabled":false}` | See also: https://github.com/prometheus-community/helm-charts/issues/106#issuecomment-700847774 |
| lapi.strategy.type | string | `"Recreate"` |  |
| lapi.secrets.csLapiSecret | string | `""` | Shared LAPI secret. Will be generated randomly if not specified. Size must be > 64 characters |
| lapi.extraSecrets | object | `{}` | Any extra secrets you may need (for example, external DB password) |
| lapi.lifecycle | object | `{}` |  |
| agent.additionalAcquisition | list | `[]` | To add custom acquisitions using available datasources (https://docs.crowdsec.net/docs/next/data_sources/intro) |
| agent.acquisition[0] | object | `{"namespace":"","podName":"","poll_without_inotify":false,"program":""}` | Specify each pod you want to process it logs (namespace, podName and program) |
| agent.acquisition[0].podName | string | `""` | to select pod logs to process |
| agent.acquisition[0].program | string | `""` | program name related to specific parser you will use (see https://hub.crowdsec.net/author/crowdsecurity/configurations/docker-logs) |
| agent.acquisition[0].poll_without_inotify | bool | `false` | If set to true, will poll the files using os.Stat instead of using inotify |
| agent.priorityClassName | string | `""` | pod priority class name |
| agent.podAnnotations | object | `{}` | Annotations to be added to agent pods, if global podAnnotations are not set |
| agent.podLabels | object | `{}` | Labels to be added to agent pods, if global podLabels are not set |
| agent.resources.limits.memory | string | `"100Mi"` |  |
| agent.resources.requests.cpu | string | `"150m"` |  |
| agent.resources.requests.memory | string | `"100Mi"` |  |
| agent.persistentVolume | object | `{"config":{"accessModes":["ReadWriteOnce"],"enabled":false,"existingClaim":"","size":"100Mi","storageClassName":""}}` | Enable persistent volumes |
| agent.persistentVolume.config | object | `{"accessModes":["ReadWriteOnce"],"enabled":false,"existingClaim":"","size":"100Mi","storageClassName":""}` | Persistent volume for config folder. Stores local config (parsers, scenarios etc.) |
| agent.env | list | `[]` | environment variables from crowdsecurity/crowdsec docker image |
| agent.nodeSelector | object | `{}` | nodeSelector for agent |
| agent.tolerations | list | `[]` | tolerations for agent |
| agent.affinity | object | `{}` | affinity for agent |
| agent.metrics | object | `{"enabled":false,"serviceMonitor":{"enabled":false}}` | Enable service monitoring (exposes "metrics" port "6060" for Prometheus) |
| agent.metrics.serviceMonitor | object | `{"enabled":false}` | See also: https://github.com/prometheus-community/helm-charts/issues/106#issuecomment-700847774 |
| agent.service.type | string | `"ClusterIP"` |  |
| agent.service.labels | object | `{}` |  |
| agent.service.annotations | object | `{}` |  |
| agent.service.externalIPs | list | `[]` |  |
| agent.service.loadBalancerIP | string | `nil` |  |
| agent.service.loadBalancerClass | string | `nil` |  |
| agent.service.externalTrafficPolicy | string | `"Cluster"` |  |
| agent.wait_for_lapi | object | `{"image":{"pullPolicy":"IfNotPresent","repository":"busybox","tag":"1.28"}}` | wait-for-lapi init container |
| agent.wait_for_lapi.image.repository | string | `"busybox"` | docker image repository name |
| agent.wait_for_lapi.image.pullPolicy | string | `"IfNotPresent"` | pullPolicy |
| agent.wait_for_lapi.image.tag | string | `"1.28"` | docker image tag |

