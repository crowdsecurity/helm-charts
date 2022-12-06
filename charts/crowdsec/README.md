# crowdsec

![Version: 0.8.0](https://img.shields.io/badge/Version-0.8.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v1.4.3](https://img.shields.io/badge/AppVersion-v1.4.3-informational?style=flat-square)

Crowdsec helm chart is an open-source, lightweight agent to detect and respond to malicious behaviors.

## Get Repo Info

```
helm repo add crowdsec https://crowdsecurity.github.io/helm-charts
helm repo update
```

## Installing the Chart

Before installing the chart, it is important to understand some key
[concepts](https://docs.crowdsec.net/docs/concepts) of CrowdSec. It will ensure
you can properly configure the chart and effectively parse logs to detect
attacks within your Kubernetes cluster.

Here are some blog posts about CrowdSec in Kubernetes:

 - [Kubernetes CrowdSec Integration – Part 1: Detection](https://www.crowdsec.net/blog/kubernetes-crowdsec-integration)
 - [Kubernetes CrowdSec Integration – Part 2: Remediation](https://www.crowdsec.net/blog/kubernetes-crowdsec-integration-remediation)
 - [How to mitigate security threats with CrowdSec in Kubernetes using Traefik](https://www.crowdsec.net/blog/how-to-mitigate-security-threats-with-crowdsec-and-traefik)


```
# Install helm chart with proper values.yaml config
helm install crowdsec crowdsec/crowdsec -f crowdsec-values.yaml -n crowdsec --create-namespace
```

## TLS authentication/encryption

By enabling TLS all communication between agents, bouncers, and LAPI is protected by certificates.

By default, cert-manager and reflector are used to create, distribute and refresh certificate secrets.

There are three secrets: $RELEASE-agent-tls, $RELEASE-bouncer-tls, and $RELEASE-lapi-tls.
Each secret contains three files: `tls.crt`, `tls.key` and `ca.crt`.

If you can't use cert-manager, you can provide an alternate mechanism to create them (see the directory hack/tls for an example),
and you'll have to set `tls.certManager.enabled=false`.

When using TLS, agents don't need username/password, and bouncers don't need an API key.


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
| image.tag | string | `""` | docker image tag |
| config.parsers | object | `{"s00-raw":{},"s01-parse":{},"s02-enrich":{}}` | To better understand stages in parsers, you can take a look at https://docs.crowdsec.net/docs/next/parsers/intro/ |
| config.scenarios | object | `{}` | to better understand how to write a scenario, you can take a look at https://docs.crowdsec.net/docs/next/scenarios/intro |
| config.postoverflows | object | `{"s00-enrich":{},"s01-whitelist":{}}` | to better understand how to write a postoverflow, you can take a look at (https://docs.crowdsec.net/docs/next/whitelist/create/#whitelist-in-postoverflows) |
| config."simulation.yaml" | string | `""` | Simulation configuration (https://docs.crowdsec.net/docs/next/scenarios/simulation/) |
| config."console.yaml" | string | `""` |  |
| config."profiles.yaml" | string | `""` | Profiles configuration (https://docs.crowdsec.net/docs/next/profiles/format/#profile-configuration-example) |
| config.notifications | object | `{}` | notifications configuration (https://docs.crowdsec.net/docs/next/notification_plugins/intro) |
| secrets.username | string | `""` | agent username (default is generated randomly) |
| secrets.password | string | `""` | agent password (default is generated randomly) |
| tls.enabled | bool | `false` | Enable TLS between LAPI, agents and bouncers (see below) |
| tls.caBundle | bool | `true` | Certificate secrets also contain a `ca.crt` file |
| tls.certManager.enabled | bool | `true` | Create TLS certificates with cert-manager (must be installed) |
| tls.bouncer.secret | string | {{ .Release.Name }}-bouncer-tls | Name of the bouncer certificate secret |
| tls.bouncer.reflector.namespaces | list | `[]` | List of namespaces where bouncers are deployed |
| tls.agent.secret | string | {{ .Release.Name }}-agent-tls | Name of the agent certificate secret |
| tls.agent.reflector.namespaces | list | `[]` | List of namespaces where agents are deployed |
| tls.lapi.secret | string | {{ .Release.Name }}-lapi-tls | Name of the lapi certificate secret |
| lapi.env | list | `[]` | environment variables from crowdsecurity/crowdsec docker image |
| lapi.ingress | object | `{"annotations":{"nginx.ingress.kubernetes.io/backend-protocol":"HTTP"},"enabled":false,"host":"","ingressClassName":""}` | Enable ingress lapi object |
| lapi.dashboard.enabled | bool | `false` | Enable Metabase Dashboard (by default disabled) |
| lapi.dashboard.image.repository | string | `"metabase/metabase"` | docker image repository name |
| lapi.dashboard.image.pullPolicy | string | `"IfNotPresent"` | pullPolicy |
| lapi.dashboard.image.tag | string | `"v0.41.5"` | docker image tag |
| lapi.dashboard.assetURL | string | `"https://crowdsec-statics-assets.s3-eu-west-1.amazonaws.com/metabase_sqlite.zip"` | Metabase SQLite static DB containing Dashboards |
| lapi.dashboard.ingress | object | `{"annotations":{"nginx.ingress.kubernetes.io/backend-protocol":"HTTP"},"enabled":false,"host":"","ingressClassName":""}` | Enable ingress object |
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
| lapi.tolerations | object | `{}` | tolerations for lapi |
| lapi.metrics | object | `{"enabled":false,"serviceMonitor":{"enabled":false}}` | Enable service monitoring (exposes "metrics" port "6060" for Prometheus) |
| lapi.metrics.serviceMonitor | object | `{"enabled":false}` | See also: https://github.com/prometheus-community/helm-charts/issues/106#issuecomment-700847774 |
| lapi.strategy.type | string | `"RollingUpdate"` |  |
| agent.acquisition[0] | object | `{"namespace":"","podName":"","program":""}` | Specify each pod you want to process it logs (namespace, podName and program) |
| agent.acquisition[0].podName | string | `""` | to select pod logs to process |
| agent.acquisition[0].program | string | `""` | program name related to specific parser you will use (see https://hub.crowdsec.net/author/crowdsecurity/configurations/docker-logs) |
| agent.resources.limits.memory | string | `"100Mi"` |  |
| agent.resources.requests.cpu | string | `"150m"` |  |
| agent.resources.requests.memory | string | `"100Mi"` |  |
| agent.persistentVolume | object | `{"config":{"accessModes":["ReadWriteOnce"],"enabled":true,"existingClaim":"","size":"100Mi","storageClassName":""}}` | Enable persistent volumes |
| agent.persistentVolume.config | object | `{"accessModes":["ReadWriteOnce"],"enabled":true,"existingClaim":"","size":"100Mi","storageClassName":""}` | Persistent volume for config folder. Stores local config (parsers, scenarios etc.) |
| agent.env | list | `[]` | environment variables from crowdsecurity/crowdsec docker image |
| agent.nodeSelector | object | `{}` | nodeSelector for agent |
| agent.tolerations | object | `{}` | tolerations for agent |
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

