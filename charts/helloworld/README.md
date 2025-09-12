# helloworld

![Version: 0.2.1](https://img.shields.io/badge/Version-0.2.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.16.0](https://img.shields.io/badge/AppVersion-1.16.0-informational?style=flat-square)

A helloWorld chart for Kubernetes using ingress nginx

## Parameters

### Image

| Name               | Description                                                | Value |
| ------------------ | ---------------------------------------------------------- | ----- |
| `image.repository` | Container image repository                                 | `""`  |
| `image.pullPolicy` | Image pull policy (Always, IfNotPresent, Never)            | `""`  |
| `image.tag`        | Image tag                                                  | `""`  |
| `imagePullSecrets` | Secrets to use for pulling images                          | `[]`  |
| `nameOverride`     | String to partially override fullname template with a name | `""`  |
| `fullnameOverride` | String to fully override fullname template with a name     | `""`  |

### ServiceAccount

| Name                         | Description                                                                                 | Value  |
| ---------------------------- | ------------------------------------------------------------------------------------------- | ------ |
| `serviceAccount.create`      | Specifies whether a service account should be created                                       | `true` |
| `serviceAccount.annotations` | Annotations to add to the service account                                                   | `{}`   |
| `serviceAccount.name`        | The name of the service account to use (if not set and create is true, a name is generated) | `""`   |
| `podAnnotations`             | Annotations to be added to pods                                                             | `{}`   |
| `podSecurityContext`         | Pod-level security context                                                                  | `{}`   |
| `securityContext`            | Container-level security context                                                            | `{}`   |

### Service

| Name           | Description             | Value  |
| -------------- | ----------------------- | ------ |
| `service.name` | Name of the service     | `""`   |
| `service.type` | Kubernetes Service type | `""`   |
| `service.port` | Service port            | `5678` |

### Ingress

| Name                  | Description                          | Value   |
| --------------------- | ------------------------------------ | ------- |
| `ingress.enabled`     | Enable ingress resource              | `false` |
| `ingress.class`       | Ingress class name                   | `""`    |
| `ingress.annotations` | Annotations for the ingress resource | `{}`    |
| `ingress.hosts`       | List of ingress hosts                | `[]`    |
| `ingress.tls`         | TLS configuration for ingress        | `[]`    |

### Resources

| Name        | Description                           | Value |
| ----------- | ------------------------------------- | ----- |
| `resources` | Resource requests and limits for pods | `{}`  |

### Autoscaling

| Name                                         | Description                            | Value   |
| -------------------------------------------- | -------------------------------------- | ------- |
| `autoscaling.enabled`                        | Enable HorizontalPodAutoscaler         | `false` |
| `autoscaling.minReplicas`                    | Minimum number of replicas             | `1`     |
| `autoscaling.maxReplicas`                    | Maximum number of replicas             | `5`     |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage      | `80`    |
| `nodeSelector`                               | Node selector rules for pod assignment | `{}`    |
| `tolerations`                                | Tolerations for pod assignment         | `[]`    |
| `affinity`                                   | Affinity rules for pod assignment      | `{}`    |

