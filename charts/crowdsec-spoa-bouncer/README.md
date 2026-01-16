# CrowdSec HAProxy SPOA Bouncer Helm Chart

This Helm chart deploys the [CrowdSec HAProxy SPOA Bouncer](https://github.com/crowdsecurity/cs-haproxy-spoa-bouncer) on a Kubernetes cluster.

The SPOA (Stream Processing Offload Agent) bouncer integrates with HAProxy to check incoming requests against CrowdSec decisions and block malicious traffic.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- CrowdSec LAPI accessible from the cluster
- A registered bouncer API key from CrowdSec

## Installation

### Quick Start

```bash
helm install spoa-bouncer crowdsec/crowdsec-spoa-bouncer \
  --set bouncer.crowdsec_key=<your-api-key> \
  --set bouncer.crowdsec_url=http://crowdsec-service.crowdsec:8080/
```

### Using an Existing Secret for API Key

```bash
# Create a secret with your API key
kubectl create secret generic spoa-bouncer-secret \
  --from-literal=CROWDSEC_KEY=<your-api-key>

# Install referencing the secret
helm install spoa-bouncer crowdsec/crowdsec-spoa-bouncer \
  --set config.existingSecret=spoa-bouncer-secret \
  --set bouncer.crowdsec_url=http://crowdsec-service.crowdsec:8080/
```

## Configuration

### Bouncer Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `bouncer.crowdsec_key` | CrowdSec LAPI API key (required unless using existingSecret) | `""` |
| `bouncer.crowdsec_url` | CrowdSec LAPI URL | `http://crowdsec-service.crowdsec.svc.cluster.local:8080/` |
| `bouncer.log_level` | Log level: `trace`, `debug`, `info`, `warn`, `error` | `info` |
| `bouncer.insecure_skip_verify` | Skip TLS verification for LAPI (for self-signed certs) | `false` |
| `bouncer.prometheus_enabled` | Enable Prometheus metrics | `true` |
| `bouncer.env` | Additional environment variables | `[]` |

### Advanced Configuration

For advanced use cases like mTLS authentication, use the `.local` configuration file:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.localConfig` | Local override configuration (.yaml.local) | `""` |
| `config.existingSecret` | Use existing secret for API key | `""` |
| `config.existingSecretKey` | Key in the existing secret | `CROWDSEC_KEY` |

#### Example: mTLS Authentication

```yaml
config:
  localConfig: |
    ca_cert_path: /etc/crowdsec/certs/ca.crt
    cert_path: /etc/crowdsec/certs/client.crt
    key_path: /etc/crowdsec/certs/client.key
```

### Per-Host Remediation (hostsDir)

Configure captcha, ban pages, and AppSec settings per host. Since host configs contain sensitive data (captcha keys, signing keys), they should be stored in a Kubernetes Secret.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.hostsDir.enabled` | Enable hosts directory mounting | `false` |
| `config.hostsDir.path` | Path where host configs are mounted | `/etc/crowdsec/bouncers/spoa-host.d` |
| `config.hostsDir.existingSecret` | Secret containing host YAML files | `""` |

#### Example: Per-Host Configuration

1. Create host configuration files:

```yaml
# default.yaml - fallback for unmatched hosts
captcha:
  provider: hcaptcha
  site_key: "your-site-key"
  secret_key: "your-secret-key"
  signing_key: "your-32-byte-minimum-signing-key-here"
ban:
  contact_us_url: "mailto:support@example.com"
```

```yaml
# myapp.yaml - specific host config
host: "myapp.example.com"
captcha:
  provider: turnstile
  site_key: "your-turnstile-site-key"
  secret_key: "your-turnstile-secret-key"
  signing_key: "your-32-byte-minimum-signing-key-here"
appsec:
  always_send: true
```

2. Create the Kubernetes Secret:

```bash
kubectl create secret generic spoa-hosts \
  --from-file=default.yaml=./hosts/default.yaml \
  --from-file=myapp.yaml=./hosts/myapp.yaml
```

3. Install the chart:

```bash
helm install spoa-bouncer crowdsec/crowdsec-spoa-bouncer \
  --set bouncer.crowdsec_key=<your-api-key> \
  --set config.hostsDir.enabled=true \
  --set config.hostsDir.existingSecret=spoa-hosts
```

The chart automatically sets `hosts_dir` in the bouncer config to point to the mounted secret.

### Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.annotations` | Service annotations | `{}` |

The service exposes port 9000 (SPOA) and port 6060 (metrics) by default.

### Metrics & Monitoring

| Parameter | Description | Default |
|-----------|-------------|---------|
| `metrics.enabled` | Enable metrics | `false` |
| `metrics.serviceMonitor.enabled` | Create ServiceMonitor for Prometheus Operator | `false` |
| `metrics.serviceMonitor.additionalLabels` | Additional labels for ServiceMonitor | `{}` |
| `metrics.serviceMonitor.namespace` | Namespace for ServiceMonitor | `""` |
| `metrics.serviceMonitor.interval` | Scrape interval | `30s` |
| `metrics.serviceMonitor.scrapeTimeout` | Scrape timeout | `10s` |

### Common Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Image repository | `crowdsecurity/spoa-bouncer` |
| `image.tag` | Image tag (defaults to appVersion) | `""` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `resources` | CPU/Memory resource requests/limits | `{}` |
| `nodeSelector` | Node labels for pod assignment | `{}` |
| `tolerations` | Tolerations for pod assignment | `[]` |
| `affinity` | Affinity rules for pod assignment | `{}` |

## HAProxy Integration

After deploying the bouncer, configure HAProxy to use it.

### HAProxy Configuration Example

```haproxy
frontend http-in
    bind *:80
    filter spoe engine crowdsec config /etc/haproxy/crowdsec-spoe.conf
    http-request deny if { var(txn.crowdsec.action) -m str ban }
```

### SPOE Configuration (crowdsec-spoe.conf)

```
[crowdsec]
spoe-agent crowdsec-agent
    messages check-request
    option var-prefix crowdsec
    timeout hello      2s
    timeout idle       2m
    timeout processing 10ms
    use-backend crowdsec-spoa

spoe-message check-request
    args src=src dst=dst method=method path=path query=query
    event on-frontend-http-request
```

### HAProxy Backend for SPOA

```haproxy
backend crowdsec-spoa
    mode tcp
    server spoa spoa-bouncer.default.svc.cluster.local:9000 check
```

## Troubleshooting

### Check bouncer logs

```bash
kubectl logs -l app.kubernetes.io/name=crowdsec-spoa-bouncer
```

### Check metrics

```bash
kubectl port-forward svc/spoa-bouncer 6060:6060
curl http://localhost:6060/metrics
```

## License

This chart is distributed under the MIT License.
