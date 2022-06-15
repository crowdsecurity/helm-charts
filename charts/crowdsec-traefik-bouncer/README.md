# crowdsec-traefik-bouncer

![Version: 0.1.1](https://img.shields.io/badge/Version-0.1.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.3.5](https://img.shields.io/badge/AppVersion-0.3.5-informational?style=flat-square)

A http service to verify request and bounce them according to decisions made by CrowdSec.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| bouncer.crowdsec_bouncer_api_key | string | `""` | bouncer api key (need to be generated from crowdsec agent) |
| bouncer.crowdsec_agent_host | string | `""` | crowdsec lapi host (ie: crowdsec-service.crowdsec.svc.cluster.local:8080) |
| replicaCount | int | `1` |  |
| image.repository | string | `"fbonalair/traefik-crowdsec-bouncer"` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.tag | string | `""` |  |
| imagePullSecrets | list | `[]` |  |
| podAnnotations | object | `{}` |  |
| podSecurityContext | object | `{}` |  |
| securityContext | object | `{}` |  |
| service.type | string | `"ClusterIP"` |  |
| service.port | int | `80` |  |
| resources | object | `{}` |  |
| nodeSelector | object | `{}` |  |
| tolerations | list | `[]` |  |
| affinity | object | `{}` |  |

