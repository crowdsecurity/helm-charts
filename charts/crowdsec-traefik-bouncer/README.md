# crowdsec-traefik-bouncer

> **:exclamation: This Helm Chart is deprecated!**

![Version: 0.1.4](https://img.shields.io/badge/Version-0.1.4-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.5.0](https://img.shields.io/badge/AppVersion-0.5.0-informational?style=flat-square)

A http service to verify request and bounce them according to decisions made by CrowdSec.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| bouncer.crowdsec_agent_host | string | `""` | crowdsec lapi host (ie: crowdsec-service.crowdsec.svc.cluster.local:8080) |
| bouncer.crowdsec_bouncer_api_key | string | `""` | bouncer api key (need to be generated from crowdsec agent) |
| bouncer.crowdsec_bouncer_gin_mode | string | `"debug"` | crowdsec_bouncer_gin_mode sets the mode of the app |
| bouncer.env | list | `[]` | environment variables |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"fbonalair/traefik-crowdsec-bouncer"` |  |
| image.tag | string | `""` |  |
| imagePullSecrets | list | `[]` |  |
| nodeSelector | object | `{}` |  |
| podAnnotations | object | `{}` |  |
| podSecurityContext | object | `{}` |  |
| priorityClassName | string | `""` |  |
| replicaCount | int | `1` |  |
| resources | object | `{}` |  |
| securityContext | object | `{}` |  |
| service.port | int | `80` |  |
| service.type | string | `"ClusterIP"` |  |
| tolerations | list | `[]` |  |

