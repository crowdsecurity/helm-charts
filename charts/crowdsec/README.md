# crowdsec

![Version: 0.19.4](https://img.shields.io/badge/Version-0.19.4-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v1.6.9](https://img.shields.io/badge/AppVersion-v1.6.9-informational?style=flat-square)

Crowdsec helm chart is an open-source, lightweight agent to detect and respond to bad behaviours.

- [Chart Repository](#chart-repository)
- [Installing the Chart](#installing-the-chart)
- [Uninstalling the Chart](#uninstalling-the-chart)
- [Authentication](#authentication)
  - [Auto registration token](#auto-registration-token)
  - [TLS client authentication](#tls-client-authentication)
  - [Cleaning of stale agents / appsec registration in the LAPI](#cleaning-of-stale-agents--appsec-registration-in-the-lapi)
- [HA configuration for the LAPI pods](#ha-configuration-for-the-lapi-pods)
  - [Database setup](#database-setup)
  - [CrowdSec setup](#crowdsec-setup)
  - [HA Test](#ha-test)
- [Setup for AppSec (WAF)](#setup-for-appsec-waf)
  - [With Traefik](#with-traefik)
  - [With Nginx](#with-nginx)
- [Values](#values)

## Chart Repository

```sh
helm repo add crowdsec https://crowdsecurity.github.io/helm-charts
helm repo update
```

## Installing the Chart

Before installing the chart, you need to understand some [concepts](https://docs.crowdsec.net/docs/concepts) of Crowdsec.
So you can configure well the chart and being able to parse logs and detect attacks inside your Kubernetes cluster.

Here is a [blog post](https://crowdsec.net/blog/kubernetes-crowdsec-integration/) about crowdsec in kubernetes.

```sh
# Create namespace for crowdsec
kubectl create ns crowdsec
# Install helm chart with proper values.yaml config
helm install crowdsec crowdsec/crowdsec -f crowdsec-values.yaml -n crowdsec
```

## Uninstalling the Chart

```sh
helm delete crowdsec -n crowdsec
```

## Authentication

This charts support two types of authentication between the agents / appsec pods and the LAPI: an auto registration token and TLS client authentication.

### Auto registration token

By default, this chart makes use of an auto registration token completely handled by the chart.
This is setup with the following part in the `values.yaml` file. Make sure to adapt to the pod IP ranges used by your cluster.

Also, when you modify the `config.config.yaml.local` entry in your own `values.yaml` make sure to put this piece in it as well.

```yaml
config:
  config.yaml.local: |
    api:
      server:
        auto_registration: # Activate if not using TLS for authentication
          enabled: true
          token: "${REGISTRATION_TOKEN}" # /!\ Do not modify this variable (auto-generated and handled by the chart)
          allowed_ranges: # /!\ Make sure to adapt to the pod IP ranges used by your cluster
            - "127.0.0.1/32"
            - "192.168.0.0/16"
            - "10.0.0.0/8"
            - "172.16.0.0/12"
```

### TLS client authentication

Currently TLS authentication is only possible between the agent and the LAPI as appsec doesn't support HTTPS yet.
The below configuration will activate TLS on the LAPI and TLS client authentication for the agent.
Certificates are renewed by default with [cert-manager](https://github.com/cert-manager/cert-manager).

```yaml
tls:
  enabled: true
  agent:
    tlsClientAuth: true
```

### Cleaning of stale agents / appsec registration in the LAPI

Both methods add a machine per pod in the LAPI. These aren't automatically cleaned and the list of machines can become large over time.
Crowdsec offers a [flush option](https://docs.crowdsec.net/docs/next/configuration/crowdsec_configuration/#flush) to clean them up.
Add the `flush:` part to your `db_config`.

```yaml
config:
  config.yaml.local: |
    db_config:
      flush:
        agents_autodelete:
          cert: 60m # This is TLS client authentication
          login_password: 60m # This includes the auto registration token as well
        ## Flush both login types if the machine has not logged in for 60 minutes or more
```

## HA configuration for the LAPI pods

You can set up multiple LAPI instances so the failure of a node does not impact
the availability of crowdsec.

To do that, we define a replica count=2 and both instances will use the same
database and CAPI credentials.

The constraints of this setup are

- no local database, but mysql or postgres (in or outside of the cluster)
- no persistent volume for LAPI configuration or data

### Database setup

If you have an existing postgres/mysql/mariadb, create a user for crowdsec and
take note of the credentials.

In this tutorial we deploy a basic instance with:

```sh
$ helm repo add bitnami https://charts.bitnami.com/bitnami
$ helm install \
    mysql bitnami/mysql \
    --create-namespace \
    -n mysql \
    --set auth.RootPassword=verysecretpassword \
    --set auth.database=crowdsec \
    --set auth.username=crowdsec \
    --set auth.password=secretpassword
```

The hostname of the DB will therefore be mysql.mysql.svc.cluster.local

Now, copy your enrollment key at [https://app.crowdsec.net/security-engines](https://app.crowdsec.net/security-engines),
by clicking 'Enroll command' and the "Kubernetes" tab. It is the same every time for your account so you can reuse it
for multiple installations.

### CrowdSec setup

Create a `crowdsec-values.yaml` file, make sure to replace the db credentials and the enrollment key:

```yaml
container_runtime: containerd

agent:
  # we are not setting up traefik but the acquisition section is required.
  acquisition:
    - namespace: traefik
      podName: traefik-*
      program: traefik
lapi:
  replicas: 2
  extraSecrets:
    dbPassword: "secretpassword"
  storeCAPICredentialsInSecret: true
  persistentVolume:
    config:
      enabled: false
    data:
      enabled: false
  env:
    - name: ENROLL_KEY
      value: "abcdefghijklmnopqrstuvwxy"
    - name: ENROLL_INSTANCE_NAME
      value: "my-k8s-cluster"
    - name: ENROLL_TAGS
      value: "k8s linux test"
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: crowdsec-lapi-secrets
          key: dbPassword
config:
  config.yaml.local: |
    db_config:
      type:     mysql
      user:     crowdsec
      password: ${DB_PASSWORD}
      db_name:  crowdsec
      host:     mysql.mysql.svc.cluster.local
      port:     3306
    api:
      server:
        auto_registration: # Activate if not using TLS for authentication
          enabled: true
          token: "${REGISTRATION_TOKEN}"  # /!\ do not change
          allowed_ranges: # /!\ adapt to the pod IP ranges used by your cluster
            - "127.0.0.1/32"
            - "192.168.0.0/16"
            - "10.0.0.0/8"
            - "172.16.0.0/12"

```

and install the crowdsec chart.

```sh
helm install \
    crowdsec crowdsec/crowdsec \
    --create-namespace \
    -n crowdsec \
    -f crowdsec-values.yaml
```

Now you can return to the [console](https://app.crowdsec.net/) to accept the enrollment.

### HA Test

As you can see, the CAPI credentials are persisted in a k8s secret

```
$ kubectl -n crowdsec get secrets crowdsec-capi-credentials -o yaml | yq '.data."online_api_credentials.yaml"' | base64 -d
url: https://api.crowdsec.net/
login: ...
password: ...
papi_url: https://papi.api.crowdsec.net/
```

You can test crowdsec availability by removing any of the LAPI pods, possibly taint the remaining nodes so it won't spawn on them,
and all the log processors will keep connecting randomly to any of the available LAPIs at any time.

## Setup for AppSec (WAF)

Below a basic configuration for AppSec (WAF)

```
# your-values.yaml (option 1)
appsec:
  enabled: true
  acquisitions:
    - source: appsec
      listen_addr: "0.0.0.0:7422"
      path: /
      appsec_config: crowdsecurity/virtual-patching
      labels:
        type: appsec
  env:
    - name: COLLECTIONS
      value: "crowdsecurity/appsec-virtual-patching"
```

Or you can also use your own custom configurations and rules for AppSec:

```yaml
# your-values.yaml (option 2)
appsec:
  enabled: true
  acquisitions:
    - source: appsec
      listen_addr: "0.0.0.0:7422"
      path: /
      appsec_config: crowdsecurity/crs-vpatch
      labels:
        type: appsec
  configs:
    mycustom-appsec-config.yaml: |
      name: crowdsecurity/crs-vpatch
      default_remediation: ban
      #log_level: debug
      outofband_rules:
        - crowdsecurity/crs
      inband_rules:
        - crowdsecurity/base-config
        - crowdsecurity/vpatch-*
  env:
    - name: COLLECTIONS
      value: "crowdsecurity/appsec-virtual-patching crowdsecurity/appsec-crs"
```

### With Traefik

In the Traefik `values.yaml`, you need to add the following configuration:

```
# traefik-values.yaml
experimental:
  plugins:
    crowdsec-bouncer:
      moduleName: github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin
      version: v1.3.3
additionalArguments:
  - "--entrypoints.web.http.middlewares=<NAMESPACE>-crowdsec-bouncer@kubernetescrd"
  - "--entrypoints.websecure.http.middlewares=<NAMESPACE>-crowdsec-bouncer@kubernetescrd"
  - "--providers.kubernetescrd"
```

And then, you can apply this middleware to your traefik ingress:

```
# crowdsec-bouncer-middleware.yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: crowdsec-bouncer
  namespace: default
spec:
  plugin:
    crowdsec-bouncer:
      enabled: true
      crowdsecMode: appsec
      crowdsecAppsecEnabled: true
      crowdsecAppsecHost: crowdsec-appsec-service:7422
      crowdsecLapiScheme: http
      crowdsecLapiHost: crowdsec-service:8080
      crowdsecLapiKey: "<YOUR_BOUNCER_KEY>"
```

### With Nginx

Following [this documentation](https://docs.crowdsec.net/u/bouncers/ingress-nginx).

In the nginx ingress `upgrade-values.yaml`, you need to add the following configuration:

```
controller:
  extraInitContainers:
    - name: init-clone-crowdsec-bouncer
      env:
        - name: APPSEC_URL
          value: "http://crowdsec-appsec-service.default.svc.cluster.local:7422"
        - name: APPSEC_FAILURE_ACTION
          value: "passthrough"
        - name: APPSEC_CONNECT_TIMEOUT
          value: "100"
        - name: APPSEC_SEND_TIMEOUT
          value: "100"
        - name: APPSEC_PROCESS_TIMEOUT
          value: "1000"
        - name: ALWAYS_SEND_TO_APPSEC
          value: "false"
        - name: SSL_VERIFY
          value: "true"
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
| config.parsers | object | `{"s00-raw":{},"s01-parse":{},"s02-enrich":{}}` | To better understand stages in parsers, you can take a look at https://docs.crowdsec.net/docs/next/parsers/intro/ Those files are only mounted in the agent pods |
| config.scenarios | object | `{}` | to better understand how to write a scenario, you can take a look at https://docs.crowdsec.net/docs/next/scenarios/intro Those files are only mounted in the agent pods |
| config.postoverflows | object | `{"s00-enrich":{},"s01-whitelist":{}}` | to better understand how to write a postoverflow, you can take a look at (https://docs.crowdsec.net/docs/next/whitelist/create/#whitelist-in-postoverflows) Those files are only mounted in the agent pods |
| config."simulation.yaml" | string | `""` | Simulation configuration (https://docs.crowdsec.net/docs/next/scenarios/simulation/) This file is only mounted in the agent pods |
| config."console.yaml" | string | `""` |  |
| config."capi_whitelists.yaml" | string | `""` |  |
| config."profiles.yaml" | string | `""` | Profiles configuration (https://docs.crowdsec.net/docs/next/profiles/format/#profile-configuration-example) This file is only mounted in the lapi pod |
| config."config.yaml.local" | string | `"api:\n  server:\n    auto_registration: # Activate if not using TLS for authentication\n      enabled: true\n      token: \"${REGISTRATION_TOKEN}\" # /!\\ Do not modify this variable (auto-generated and handled by the chart)\n      allowed_ranges: # /!\\ Make sure to adapt to the pod IP ranges used by your cluster\n        - \"127.0.0.1/32\"\n        - \"192.168.0.0/16\"\n        - \"10.0.0.0/8\"\n        - \"172.16.0.0/12\"\n# db_config:\n#   type:     postgresql\n#   user:     crowdsec\n#   password: ${DB_PASSWORD}\n#   db_name:  crowdsec\n#   host:     192.168.0.2\n#   port:     5432\n#   sslmode:  require\n"` | General configuration (https://docs.crowdsec.net/docs/configuration/crowdsec_configuration/#configuration-example) This file is only mounted in the lapi pod |
| config.notifications | object | `{}` | notifications configuration (https://docs.crowdsec.net/docs/next/notification_plugins/intro) Those files are only mounted in the lapi pod |
| config."agent_config.yaml.local" | string | `""` |  |
| config."appsec_config.yaml.local" | string | `""` |  |
| tls.enabled | bool | `false` |  |
| tls.caBundle | bool | `true` |  |
| tls.insecureSkipVerify | bool | `false` |  |
| tls.certManager.enabled | bool | `true` |  |
| tls.certManager.issuerRef | object | `{}` | Use existing issuer to sign certificates. Leave empty to generate a self-signed issuer |
| tls.certManager.secretTemplate | object | `{"annotations":{},"labels":{}}` | Add annotations and/or labels to generated secret |
| tls.certManager.duration | string | `"2160h"` | duration for Certificate resources |
| tls.certManager.renewBefore | string | `"720h"` | renewBefore for Certificate resources |
| tls.bouncer.secret | string | `"{{ .Release.Name }}-bouncer-tls"` |  |
| tls.bouncer.reflector.namespaces | list | `[]` |  |
| tls.agent.tlsClientAuth | bool | `true` |  |
| tls.agent.secret | string | `"{{ .Release.Name }}-agent-tls"` |  |
| tls.agent.reflector.namespaces | list | `[]` |  |
| tls.appsec.tlsClientAuth | bool | `true` |  |
| tls.appsec.secret | string | `"{{ .Release.Name }}-agent-tls"` |  |
| tls.appsec.reflector.namespaces | list | `[]` |  |
| tls.lapi.secret | string | `"{{ .Release.Name }}-lapi-tls"` |  |
| tls.lapi.reflector.namespaces | list | `[]` |  |
| secrets.username | string | `""` | agent username (default is generated randomly) |
| secrets.password | string | `""` | agent password (default is generated randomly) |
| secrets.externalSecret.name | string | `""` |  |
| secrets.externalSecret.csLapiSecretKey | string | `""` |  |
| secrets.externalSecret.registrationTokenKey | string | `""` |  |
| lapi.enabled | bool | `true` | enable lapi (by default enabled) |
| lapi.replicas | int | `1` | replicas for local API |
| lapi.env | list | `[]` | environment variables from crowdsecurity/crowdsec docker image |
| lapi.envFrom | list | `[]` |  |
| lapi.ingress | object | `{"annotations":{"nginx.ingress.kubernetes.io/backend-protocol":"HTTP"},"enabled":false,"host":"","ingressClassName":""}` | Enable ingress lapi object |
| lapi.priorityClassName | string | `""` | pod priority class name |
| lapi.deployAnnotations | object | `{}` | Annotations to be added to lapi deployment |
| lapi.podAnnotations | object | `{}` | Annotations to be added to lapi pods, if global podAnnotations are not set |
| lapi.podLabels | object | `{}` | Labels to be added to lapi pods, if global podLabels are not set |
| lapi.extraInitContainers | list | `[]` | Extra init containers to be added to lapi pods |
| lapi.extraVolumes | list | `[]` | Extra volumes to be added to lapi pods |
| lapi.extraVolumeMounts | list | `[]` | Extra volumeMounts to be added to lapi pods |
| lapi.resources | object | `{"limits":{"cpu":"500m","memory":"500Mi"},"requests":{"cpu":"500m","memory":"500Mi"}}` | resources for lapi |
| lapi.dashboard.enabled | bool | `false` | Enable Metabase Dashboard (by default disabled) |
| lapi.dashboard.env | list | `[]` | see https://www.metabase.com/docs/latest/configuring-metabase/environment-variables |
| lapi.dashboard.image.repository | string | `"metabase/metabase"` | docker image repository name |
| lapi.dashboard.image.pullPolicy | string | `"IfNotPresent"` | pullPolicy |
| lapi.dashboard.image.tag | string | `"v0.46.6.1"` | docker image tag |
| lapi.dashboard.assetURL | string | `"https://crowdsec-statics-assets.s3-eu-west-1.amazonaws.com/metabase_sqlite.zip"` | Metabase SQLite static DB containing Dashboards |
| lapi.dashboard.resources | object | `{}` | resources for metabase dashboard |
| lapi.dashboard.ingress | object | `{"annotations":{"nginx.ingress.kubernetes.io/backend-protocol":"HTTP"},"enabled":false,"host":"","ingressClassName":""}` | Enable ingress object |
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
| lapi.metrics | object | `{"enabled":true,"podMonitor":{"additionalLabels":{},"enabled":false},"serviceMonitor":{"additionalLabels":{},"enabled":false}}` | Enable service monitoring (exposes "metrics" port "6060" for Prometheus) |
| lapi.metrics.serviceMonitor | object | `{"additionalLabels":{},"enabled":false}` | See also: https://github.com/prometheus-community/helm-charts/issues/106#issuecomment-700847774 |
| lapi.metrics.podMonitor | object | `{"additionalLabels":{},"enabled":false}` | See also: https://github.com/prometheus-community/helm-charts/issues/106#issuecomment-700847774 |
| lapi.strategy.type | string | `"Recreate"` |  |
| lapi.secrets.csLapiSecret | string | `""` | Shared LAPI secret. Will be generated randomly if not specified. Size must be > 64 characters |
| lapi.secrets.registrationToken | string | `""` | Registration Token for Appsec. Will be generated randomly if not specified. Size must be > 48 characters |
| lapi.extraSecrets | object | `{}` | Any extra secrets you may need (for example, external DB password) |
| lapi.lifecycle | object | `{}` |  |
| lapi.storeCAPICredentialsInSecret | bool | `false` | If set to true, the Central API credentials will be stored in a secret (to use when lapi replicas > 1) |
| agent.enabled | bool | `true` | enable agent (by default enabled) |
| agent.isDeployment | bool | `false` | Switch to Deployment instead of DaemonSet (In some cases, you may want to deploy the agent as a Deployment) |
| agent.lapiURL | string | `""` | lapiURL for agent to connect to (default is the lapi service URL) |
| agent.lapiHost | string | `""` | lapiHost for agent to connect to (default is the lapi service) |
| agent.lapiPort | int | `8080` | lapiPort for agent to connect to (default is the lapi service port) |
| agent.replicas | int | `1` | replicas for agent if isDeployment is set to true |
| agent.strategy | object | `{"type":"Recreate"}` | strategy for agent if isDeployment is set to true |
| agent.ports | list | `[]` | add your custom ports here, by default we expose port 6060 for metrics if metrics is enabled |
| agent.additionalAcquisition | list | `[]` | To add custom acquisitions using available datasources (https://docs.crowdsec.net/docs/next/data_sources/intro) |
| agent.acquisition | list | `[]` | Specify each pod you want to process it logs (namespace, podName and program) |
| agent.priorityClassName | string | `""` | pod priority class name |
| agent.daemonsetAnnotations | object | `{}` | Annotations to be added to agent daemonset |
| agent.deploymentAnnotations | object | `{}` | Annotations to be added to agent deployment |
| agent.podAnnotations | object | `{}` | Annotations to be added to agent pods, if global podAnnotations are not set |
| agent.podLabels | object | `{}` | Labels to be added to agent pods, if global podLabels are not set |
| agent.extraInitContainers | list | `[]` | Extra init containers to be added to agent pods |
| agent.extraVolumes | list | `[]` | Extra volumes to be added to agent pods |
| agent.extraVolumeMounts | list | `[]` | Extra volumeMounts to be added to agent pods |
| agent.resources.limits.memory | string | `"250Mi"` |  |
| agent.resources.limits.cpu | string | `"500m"` |  |
| agent.resources.requests.cpu | string | `"500m"` |  |
| agent.resources.requests.memory | string | `"250Mi"` |  |
| agent.persistentVolume | object | `{"config":{"accessModes":["ReadWriteOnce"],"enabled":false,"existingClaim":"","size":"100Mi","storageClassName":""}}` | Enable persistent volumes |
| agent.persistentVolume.config | object | `{"accessModes":["ReadWriteOnce"],"enabled":false,"existingClaim":"","size":"100Mi","storageClassName":""}` | Persistent volume for config folder. Stores local config (parsers, scenarios etc.) |
| agent.hostVarLog | bool | `true` | Enable hostPath to /var/log |
| agent.env | list | `[]` | environment variables from crowdsecurity/crowdsec docker image |
| agent.nodeSelector | object | `{}` | nodeSelector for agent |
| agent.tolerations | list | `[]` | tolerations for agent |
| agent.affinity | object | `{}` | affinity for agent |
| agent.livenessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/metrics","port":"metrics","scheme":"HTTP"},"periodSeconds":10,"successThreshold":1,"timeoutSeconds":5}` | livenessProbe for agent |
| agent.readinessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/metrics","port":"metrics","scheme":"HTTP"},"periodSeconds":10,"successThreshold":1,"timeoutSeconds":5}` | readinessProbe for agent |
| agent.startupProbe | object | `{"failureThreshold":30,"httpGet":{"path":"/metrics","port":"metrics","scheme":"HTTP"},"periodSeconds":10,"successThreshold":1,"timeoutSeconds":5}` | startupProbe for agent |
| agent.metrics | object | `{"enabled":true,"podMonitor":{"additionalLabels":{},"enabled":false},"serviceMonitor":{"additionalLabels":{},"enabled":false}}` | Enable service monitoring (exposes "metrics" port "6060" for Prometheus) |
| agent.metrics.serviceMonitor | object | `{"additionalLabels":{},"enabled":false}` | See also: https://github.com/prometheus-community/helm-charts/issues/106#issuecomment-700847774 |
| agent.metrics.podMonitor | object | `{"additionalLabels":{},"enabled":false}` | See also: https://github.com/prometheus-community/helm-charts/issues/106#issuecomment-700847774 |
| agent.service.type | string | `"ClusterIP"` |  |
| agent.service.labels | object | `{}` |  |
| agent.service.annotations | object | `{}` |  |
| agent.service.externalIPs | list | `[]` |  |
| agent.service.loadBalancerIP | string | `nil` |  |
| agent.service.loadBalancerClass | string | `nil` |  |
| agent.service.externalTrafficPolicy | string | `"Cluster"` |  |
| agent.service.ports | list | `[]` | ports for agent service, if metrics is enabled, it will expose port 6060 by default |
| agent.wait_for_lapi | object | `{"image":{"pullPolicy":"IfNotPresent","repository":"busybox","tag":"1.28"}}` | wait-for-lapi init container |
| agent.wait_for_lapi.image.repository | string | `"busybox"` | docker image repository name |
| agent.wait_for_lapi.image.pullPolicy | string | `"IfNotPresent"` | pullPolicy |
| agent.wait_for_lapi.image.tag | string | `"1.28"` | docker image tag |
| appsec | object | `{"acquisitions":[],"affinity":{},"configs":{},"deployAnnotations":{},"enabled":false,"env":[],"extraInitContainers":[],"extraVolumeMounts":[],"extraVolumes":[],"lapiHost":"","lapiPort":8080,"lapiURL":"","livenessProbe":{"failureThreshold":3,"httpGet":{"path":"/metrics","port":"metrics","scheme":"HTTP"},"periodSeconds":10,"successThreshold":1,"timeoutSeconds":5},"metrics":{"enabled":true,"podMonitor":{"additionalLabels":{},"enabled":false},"serviceMonitor":{"additionalLabels":{},"enabled":false}},"nodeSelector":{},"podAnnotations":{},"podLabels":{},"priorityClassName":"","readinessProbe":{"failureThreshold":3,"httpGet":{"path":"/metrics","port":"metrics","scheme":"HTTP"},"periodSeconds":10,"successThreshold":1,"timeoutSeconds":5},"replicas":1,"resources":{"limits":{"cpu":"500m","memory":"250Mi"},"requests":{"cpu":"500m","memory":"250Mi"}},"rules":{},"service":{"annotations":{},"externalIPs":[],"externalTrafficPolicy":"Cluster","labels":{},"loadBalancerClass":null,"loadBalancerIP":null,"type":"ClusterIP"},"startupProbe":{"failureThreshold":30,"httpGet":{"path":"/metrics","port":"metrics","scheme":"HTTP"},"periodSeconds":10,"successThreshold":1,"timeoutSeconds":5},"strategy":{"type":"Recreate"},"tolerations":[],"wait_for_lapi":{"image":{"pullPolicy":"IfNotPresent","repository":"busybox","tag":"1.28"}}}` | Enable AppSec (https://docs.crowdsec.net/docs/next/appsec/intro) |
| appsec.enabled | bool | `false` | Enable AppSec (by default disabled) |
| appsec.lapiURL | string | `""` | lapiURL for agent to connect to (default is the lapi service URL) |
| appsec.lapiHost | string | `""` | lapiHost for agent to connect to (default is the lapi service) |
| appsec.lapiPort | int | `8080` | lapiPort for agent to connect to (default is the lapi service port) |
| appsec.replicas | int | `1` | replicas for Appsec |
| appsec.strategy | object | `{"type":"Recreate"}` | strategy for appsec deployment |
| appsec.acquisitions | list | `[]` | Additional acquisitions for AppSec |
| appsec.configs | object | `{}` | appsec_configs (https://docs.crowdsec.net/docs/next/appsec/configuration): key is the filename, value is the config content |
| appsec.rules | object | `{}` | appsec_rules (https://docs.crowdsec.net/docs/next/appsec/rules_syntax) |
| appsec.priorityClassName | string | `""` | priorityClassName for appsec pods |
| appsec.deployAnnotations | object | `{}` | Annotations to be added to appsec deployment |
| appsec.podAnnotations | object | `{}` | podAnnotations for appsec pods |
| appsec.podLabels | object | `{}` | podLabels for appsec pods |
| appsec.extraInitContainers | list | `[]` | extraInitContainers for appsec pods |
| appsec.extraVolumes | list | `[]` | Extra volumes to be added to appsec pods |
| appsec.extraVolumeMounts | list | `[]` | Extra volumeMounts to be added to appsec pods |
| appsec.resources | object | `{"limits":{"cpu":"500m","memory":"250Mi"},"requests":{"cpu":"500m","memory":"250Mi"}}` | resources for appsec pods |
| appsec.env | list | `[]` | environment variables |
| appsec.nodeSelector | object | `{}` | nodeSelector for appsec |
| appsec.tolerations | list | `[]` | tolerations for appsec |
| appsec.affinity | object | `{}` | affinity for appsec |
| appsec.livenessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/metrics","port":"metrics","scheme":"HTTP"},"periodSeconds":10,"successThreshold":1,"timeoutSeconds":5}` | livenessProbe for appsec |
| appsec.readinessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/metrics","port":"metrics","scheme":"HTTP"},"periodSeconds":10,"successThreshold":1,"timeoutSeconds":5}` | readinessProbe for appsec |
| appsec.startupProbe | object | `{"failureThreshold":30,"httpGet":{"path":"/metrics","port":"metrics","scheme":"HTTP"},"periodSeconds":10,"successThreshold":1,"timeoutSeconds":5}` | startupProbe for appsec |
| appsec.metrics | object | `{"enabled":true,"podMonitor":{"additionalLabels":{},"enabled":false},"serviceMonitor":{"additionalLabels":{},"enabled":false}}` | Enable service monitoring (exposes "metrics" port "6060" for Prometheus and "7422" for AppSec)  |
| appsec.metrics.serviceMonitor | object | `{"additionalLabels":{},"enabled":false}` | See also: https://github.com/prometheus-community/helm-charts/issues/106#issuecomment-700847774 |
| appsec.metrics.podMonitor | object | `{"additionalLabels":{},"enabled":false}` | See also: https://github.com/prometheus-community/helm-charts/issues/106#issuecomment-700847774 |
| appsec.wait_for_lapi | object | `{"image":{"pullPolicy":"IfNotPresent","repository":"busybox","tag":"1.28"}}` | wait-for-lapi init container |
| appsec.wait_for_lapi.image.repository | string | `"busybox"` | docker image repository name |
| appsec.wait_for_lapi.image.pullPolicy | string | `"IfNotPresent"` | pullPolicy |
| appsec.wait_for_lapi.image.tag | string | `"1.28"` | docker image tag |
