# crowdsec

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.2.0](https://img.shields.io/badge/AppVersion-1.2.0-informational?style=flat-square)

Crowdsec helm chart is an open-source, lightweight agent to detect and respond to bad behaviours.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| image.repository | string | `"crowdsecurity/crowdsec"` | docker image repository name |
| image.pullPolicy | string | `"IfNotPresent"` | pullPolicy |
| image.tag | string | `"latest"` | docker image tag |
| secrets | object | `{"password":"","username":""}` |  secrets can be provided be env variables |
| secrets.username | string | `""` | agent username (default is generated randomly) |
| secrets.password | string | `""` | agent password (default is generated randomly) |
| lapi.env | list | `[{"name":"DISABLE_AGENT","value":"true"}]` | environment variables from crowdsecurity/crowdsec docker image |
| lapi.dashboard.enabled | bool | `false` | Enable Metabase Dashboard (by default disabled) |
| lapi.dashboard.image.repository | string | `"metabase/metabase"` | docker image repository name |
| lapi.dashboard.image.pullPolicy | string | `"IfNotPresent"` | pullPolicy |
| lapi.dashboard.image.tag | string | `"v0.37.5"` | docker image tag |
| lapi.dashboard.assetURL | string | `"https://crowdsec-statics-assets.s3-eu-west-1.amazonaws.com/metabase_sqlite.zip"` | Metabase SQLite static DB containing Dashboards |
| lapi.resources.limits.memory | string | `"100Mi"` |  |
| lapi.resources.requests.cpu | string | `"150m"` |  |
| lapi.resources.requests.memory | string | `"100Mi"` |  |
| agent.acquisition[0] | object | `{"namespace":"ingress-nginx","podName":"ingress-nginx-controller-*","program":"nginx"}` | Specify each pod you want to process it logs (namespace, podName and program) |
| agent.acquisition[0].podName | string | `"ingress-nginx-controller-*"` | to select pod logs to process |
| agent.acquisition[0].program | string | `"nginx"` | program name related to specific parser you will use (see https://hub.crowdsec.net/author/crowdsecurity/configurations/docker-logs) |
| agent.resources.limits.memory | string | `"100Mi"` |  |
| agent.resources.requests.cpu | string | `"150m"` |  |
| agent.resources.requests.memory | string | `"100Mi"` |  |
| agent.env | list | `[]` | environment variables from crowdsecurity/crowdsec docker image |

