# crowdsec-traefik-bouncer

> [!WARNING]
> This chart is now deprecated and has been replaced by the [Crowdsec Bouncer Traefik Plugin](https://plugins.traefik.io/plugins/6335346ca4caa9ddeffda116/crowdsec-bouncer-traefik-plugin). Please note that there will be no further support for this chart moving forward.

If you wish to continue using the chart the available values are within the Details section

<details>
  
![Version: 0.1.3](https://img.shields.io/badge/Version-0.1.3-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.5.0](https://img.shields.io/badge/AppVersion-0.5.0-informational?style=flat-square)

A http service to verify request and bounce them according to decisions made by CrowdSec.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| bouncer.crowdsec_bouncer_api_key | string | `""` | bouncer api key (need to be generated from crowdsec agent) |
| bouncer.crowdsec_agent_host | string | `""` | crowdsec lapi host (ie: crowdsec-service.crowdsec.svc.cluster.local:8080) |
| bouncer.crowdsec_bouncer_gin_mode | string | `"debug"` | crowdsec_bouncer_gin_mode sets the mode of the app |
| bouncer.env | list | `[]` | environment variables |
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
| priorityClassName | string | `""` |  |

</details>


