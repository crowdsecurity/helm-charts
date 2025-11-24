# crowdsec-traefik-bouncer

> **:exclamation: This Helm Chart is deprecated!**

![Version: 0.1.4](https://img.shields.io/badge/Version-0.1.4-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.5.0](https://img.shields.io/badge/AppVersion-0.5.0-informational?style=flat-square)

A http service to verify request and bounce them according to decisions made by CrowdSec.

## Parameters

### Bouncer

| Name                                | Description                                                                | Value |
| ----------------------------------- | -------------------------------------------------------------------------- | ----- |
| `bouncer.crowdsec_bouncer_api_key`  | Bouncer API key (must be generated from CrowdSec agent)                    | `""`  |
| `bouncer.crowdsec_agent_host`       | CrowdSec LAPI host (e.g. crowdsec-service.crowdsec.svc.cluster.local:8080) | `""`  |
| `bouncer.crowdsec_bouncer_gin_mode` | Gin mode for the bouncer app (debug, release, test)                        | `""`  |
| `bouncer.env`                       | Additional environment variables for the bouncer container                 | `[]`  |
| `replicaCount`                      | Number of replicas for the bouncer Deployment                              | `1`   |

### Image

| Name                 | Description                                            | Value |
| -------------------- | ------------------------------------------------------ | ----- |
| `image.repository`   | Container image repository                             | `""`  |
| `image.pullPolicy`   | Image pull policy (Always, IfNotPresent, Never)        | `""`  |
| `image.tag`          | Image tag (defaults to chart appVersion if empty)      | `""`  |
| `imagePullSecrets`   | Image pull secrets (list of objects with `name` field) | `[]`  |
| `podAnnotations`     | Annotations applied to bouncer pods                    | `{}`  |
| `podSecurityContext` | Pod-level security context                             | `{}`  |
| `securityContext`    | Container-level security context                       | `{}`  |

### Service

| Name           | Description                  | Value |
| -------------- | ---------------------------- | ----- |
| `service.type` | Kubernetes Service type      | `""`  |
| `service.port` | Service port for the bouncer | `80`  |

### Resources

| Name                | Description                                   | Value |
| ------------------- | --------------------------------------------- | ----- |
| `resources`         | Resource requests and limits for bouncer pods | `{}`  |
| `nodeSelector`      | Node selector rules for scheduling pods       | `{}`  |
| `tolerations`       | Tolerations for scheduling pods               | `[]`  |
| `affinity`          | Affinity rules for scheduling pods            | `{}`  |
| `priorityClassName` | PriorityClass name for pods                   | `""`  |


