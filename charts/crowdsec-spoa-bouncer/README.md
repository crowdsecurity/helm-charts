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

After deploying the bouncer, configure HAProxy to use it. See the [official documentation](https://docs.crowdsec.net/u/bouncers/haproxy_spoa/) for complete details.

### HAProxy Global Configuration

Add the Lua script and template paths to your HAProxy global section:

```haproxy
global
    [...]
    lua-prepend-path /usr/lib/crowdsec-haproxy-spoa-bouncer/lua/?.lua
    lua-load /usr/lib/crowdsec-haproxy-spoa-bouncer/lua/crowdsec.lua
    setenv CROWDSEC_BAN_TEMPLATE_PATH /var/lib/crowdsec-haproxy-spoa-bouncer/html/ban.html
    setenv CROWDSEC_CAPTCHA_TEMPLATE_PATH /var/lib/crowdsec-haproxy-spoa-bouncer/html/captcha.html
```

For AppSec (WAF) integration, also add:

```haproxy
global
    tune.bufsize 65536

defaults
    option http-buffer-request
```

### HAProxy Frontend Configuration

```haproxy
frontend http-in
    bind *:80
    filter spoe engine crowdsec config /etc/haproxy/crowdsec.cfg

    # Select which SPOE group to send (with/without body)
    acl body_within_limit req.body_size -m int le 51200  # 50KB - stay safely under SPOE frame limit
    http-request send-spoe-group crowdsec crowdsec-http-body if body_within_limit || !{ req.body_size -m found }
    http-request send-spoe-group crowdsec crowdsec-http-no-body if !body_within_limit { req.body_size -m found }

    http-request set-header X-Crowdsec-Remediation %[var(txn.crowdsec.remediation)]

    ## Handle 302 redirect for successful captcha validation (redirect to current request URL)
    http-request redirect code 302 location %[url] if { var(txn.crowdsec.remediation) -m str "allow" } { var(txn.crowdsec.redirect) -m found }

    ## Call lua script only for ban and captcha remediations (performance optimization)
    http-request lua.crowdsec_handle if { var(txn.crowdsec.remediation) -m str "captcha" }
    http-request lua.crowdsec_handle if { var(txn.crowdsec.remediation) -m str "ban" }

    ## Handle captcha cookie management via HAProxy
    ## Set captcha cookie when SPOA provides captcha_status (pending or valid)
    http-after-response set-header Set-Cookie %[var(txn.crowdsec.captcha_cookie)] if { var(txn.crowdsec.captcha_status) -m found } { var(txn.crowdsec.captcha_cookie) -m found }
    ## Clear captcha cookie when cookie exists but no captcha_status (Allow decision)
    http-after-response set-header Set-Cookie %[var(txn.crowdsec.captcha_cookie)] if { var(txn.crowdsec.captcha_cookie) -m found } !{ var(txn.crowdsec.captcha_status) -m found }

    use_backend your-backend

backend crowdsec-spoa
    mode tcp
    server spoa spoa-bouncer.default.svc.cluster.local:9000 check
```

### SPOE Configuration (crowdsec.cfg)

Create `/etc/haproxy/crowdsec.cfg` with the SPOE agent and message definitions. See the [official SPOE configuration](https://docs.crowdsec.net/u/bouncers/haproxy_spoa/) for the complete file.

### Mounting Lua Scripts and Templates in HAProxy

The Lua scripts and HTML templates must be available to HAProxy. Download them from the [cs-haproxy-spoa-bouncer GitHub repository](https://github.com/crowdsecurity/cs-haproxy-spoa-bouncer) and create ConfigMaps:

```bash
# Clone or download the files from the repository
git clone https://github.com/crowdsecurity/cs-haproxy-spoa-bouncer.git
cd cs-haproxy-spoa-bouncer

# Create ConfigMap for Lua scripts (includes all required .lua files)
kubectl create configmap crowdsec-lua --from-file=lua/

# Create ConfigMap for HTML templates
kubectl create configmap crowdsec-templates --from-file=html/
```

Then mount these in your HAProxy deployment:

```yaml
spec:
  containers:
    - name: haproxy
      volumeMounts:
        - name: crowdsec-lua
          mountPath: /usr/lib/crowdsec-haproxy-spoa-bouncer/lua
        - name: crowdsec-templates
          mountPath: /var/lib/crowdsec-haproxy-spoa-bouncer/html
  volumes:
    - name: crowdsec-lua
      configMap:
        name: crowdsec-lua
    - name: crowdsec-templates
      configMap:
        name: crowdsec-templates
```

### Real Client IP Behind CDN/Proxy

If HAProxy is behind a CDN or reverse proxy, extract the real client IP before the SPOE groups:

```haproxy
    # Extract real IP from header (adjust header name as needed)
    http-request set-src hdr(X-Real-IP) if { hdr(X-Real-IP) -m found }
    # Or for Cloudflare:
    # http-request set-src hdr(CF-Connecting-IP) if { hdr(CF-Connecting-IP) -m found }
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
