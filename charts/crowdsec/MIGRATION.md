# Migrating from 1.x to 2.0

Version 2.0 is a rewrite of the chart. The goals: one way to do each thing, no hidden interactions between options,
standard Kubernetes conventions, and an upstream image used as-is (the custom entrypoint is gone).

`values.schema.json` is now strict, so any 1.x key left in your values makes `helm install/upgrade` fail and names the key.
Use the tables below to translate them.

## Breaking changes at a glance

1. **LAPI requires an external PostgreSQL or MySQL database.** SQLite and the LAPI persistent volumes are gone;
   LAPI is a stateless Deployment that can run several replicas.
2. **Resource names changed** to `<release>-crowdsec-<component>` (or `<release>-<component>` when the release name contains `crowdsec`).
   For a release named `crowdsec`:

   | 1.x | 2.0 |
   |-----|-----|
   | `crowdsec-service` (LAPI) | `crowdsec-lapi` |
   | `crowdsec-appsec-service` | `crowdsec-appsec` |
   | `crowdsec-agent-service` | `crowdsec-agent` |
   | `crowdsec-lapi-secrets` | `crowdsec-auth` |

   **Update the LAPI and AppSec URLs in your bouncers' configuration.**
3. Labels follow the `app.kubernetes.io/*` conventions. Selectors changed, so Deployments and DaemonSets are replaced on upgrade.
4. The agent no longer supports Docker JSON logs out of the box (see [Docker runtime](#docker-runtime)).
5. Persistence of agent and LAPI configuration directories is removed: configuration comes from values only.

## Upgrade procedure

1. Set up a PostgreSQL or MySQL database for LAPI (see the README for a CloudNativePG example) and store its password in a Secret.
2. Optionally, keep your existing secrets so that registered machines keep working:
   ```sh
   kubectl -n crowdsec get secret crowdsec-lapi-secrets -o jsonpath='{.data}'
   kubectl -n crowdsec create secret generic crowdsec-auth \
     --from-literal=registrationToken=<registrationToken> --from-literal=csLapiSecret=<csLapiSecret>
   ```
   and set `auth.existingSecret: crowdsec-auth`.
3. To keep your Console identity, reuse the Central API credentials of 1.x:
   - from the `<release>-capi-credentials` Secret, if it exists (it is reused automatically when its name matches the new one,
     otherwise set `lapi.onlineAPI.existingSecret`);
   - or from `/etc/crowdsec/online_api_credentials.yaml` in the LAPI pod:
     ```sh
     kubectl -n crowdsec exec deploy/crowdsec-lapi -- cat /etc/crowdsec/online_api_credentials.yaml > online_api_credentials.yaml
     kubectl -n crowdsec create secret generic crowdsec-capi-credentials --from-file=online_api_credentials.yaml
     ```
4. Bouncer API keys, alerts and decisions are stored in the database. When moving from SQLite, either re-register
   the bouncers (`cscli bouncers add`, or `BOUNCER_KEY_<name>` variables to keep the same keys) or migrate the data.
5. When keeping the 1.x database, 1.x LAPI pods left one machine each (named after the pod), which are never cleaned up
   automatically. 2.0 uses a single `<release>-crowdsec-lapi` machine: delete the old ones with `cscli machines delete`.
6. Translate your values with the tables below, then `helm uninstall` the 1.x release and install 2.0
   (an in-place upgrade also works, but the workloads are recreated anyway because their selectors changed).

## Values mapping

### Global

| 1.x | 2.0 |
|-----|-----|
| `container_runtime` | removed: CRI log format is assumed (see [Docker runtime](#docker-runtime)) |
| `image.pullSecrets` | `imagePullSecrets` |
| `image.kubectl.*` | `lapi.onlineAPI.registrationJob.image.*` |
| `podLabels`, `podAnnotations` | unchanged, now **merged** with the component ones (1.x ignored component labels when global ones were set) |
| `secrets.username`, `secrets.password` | removed: agents register with the token or a client certificate |
| `secrets.externalSecret.name` | `auth.existingSecret` (keys must be named `registrationToken` and `csLapiSecret`) |
| `lapi.secrets.registrationToken`, `lapi.secrets.csLapiSecret` | put them in a Secret referenced by `auth.existingSecret` |
| `lapi.extraSecrets` | create your own Secret and use `lapi.env` / `lapi.envFrom` |

### Configuration files (`config.*`)

All files are now set per component, with `<component>.files` (any path under `/etc/crowdsec`) and `<component>.config`
(structured settings merged into `config.yaml.local`).

| 1.x | 2.0 |
|-----|-----|
| `config.parsers.<stage>.<file>` | `agent.files["parsers/<stage>/<file>"]` |
| `config.scenarios.<file>` | `agent.files["scenarios/<file>"]` |
| `config.postoverflows.<stage>.<file>` | `agent.files["postoverflows/<stage>/<file>"]` |
| `config["simulation.yaml"]` | `agent.files["simulation.yaml"]` |
| `config["agent_config.yaml.local"]` (string) | `agent.config` (YAML object) |
| `config["profiles.yaml"]` | `lapi.files["profiles.yaml"]` |
| `config["console.yaml"]` | `lapi.files["console.yaml"]` |
| `config.notifications.<file>` | `lapi.files["notifications/<file>"]` |
| `config["capi_whitelists.yaml"]` | `lapi.files["capi_whitelists.yaml"]` and `lapi.config.api.server.capi_whitelists_path: /etc/crowdsec/capi_whitelists.yaml` (deprecated upstream, prefer [allowlists](https://docs.crowdsec.net/docs/next/local_api/centralized_allowlists)) |
| `config["config.yaml.local"]` (string) | `lapi.config` (YAML object). Database and auto-registration settings are now generated from `lapi.database`; only keep your other settings |
| `config["appsec_config.yaml.local"]` | `appsec.config` |

Example:

```yaml
# 1.x
config:
  config.yaml.local: |
    db_config:
      max_open_conns: 50
  parsers:
    s01-parse:
      my-parser.yaml: |
        ...
# 2.0
lapi:
  config:
    db_config:
      max_open_conns: 50
agent:
  files:
    parsers/s01-parse/my-parser.yaml: |
      ...
```

### LAPI

| 1.x | 2.0 |
|-----|-----|
| `lapi.persistentVolume.*` | removed: configure `lapi.database` |
| `lapi.storeCAPICredentialsInSecret`, `lapi.storeLAPICscliCredentialsInSecret` | removed: Central API credentials are always stored in a Secret, cscli credentials are regenerated at startup |
| `lapi.env` `DISABLE_ONLINE_API=true` | `lapi.onlineAPI.enabled: false` |
| `lapi.env` `ENROLL_KEY`, `ENROLL_INSTANCE_NAME`, `ENROLL_TAGS` | `lapi.console.enrollKey`, `lapi.console.instanceName`, `lapi.console.tags` |
| `lapi.deployAnnotations` | `lapi.annotations` |
| `lapi.ingress.ingressClassName` | `lapi.ingress.className` |
| `lapi.service.externalIPs`, `loadBalancerIP`, `loadBalancerClass`, `externalTrafficPolicy` | `lapi.service.extraSpec` (any Service spec field) |
| `lapi.metrics.enabled` | removed: the metrics port is always exposed |
| `lapi.metrics.serviceMonitor.additionalLabels` | `lapi.metrics.serviceMonitor.labels` |
| `lapi.metrics.serviceMonitor` `attachMetadata.node` | removed: the `machine` label (node name) is still added, without needing Prometheus access to Node objects |
| `lapi.metrics.podMonitor` | removed: use `lapi.metrics.serviceMonitor` |
| `lapi.lifecycle` | unchanged |
| `lapi.strategy` | unchanged, now defaults to `RollingUpdate` |

### Agent

| 1.x | 2.0 |
|-----|-----|
| `agent.isDeployment: true` | `agent.kind: Deployment` |
| `agent.acquisition` (`namespace`, `podName`, `program`) | `agent.podLogs` (`namespace`, `pod`, `program`) |
| `agent.acquisition[].poll_without_inotify` | use a raw entry in `agent.acquisition` |
| `agent.additionalAcquisition` | `agent.acquisition` |
| `agent.env` `COLLECTIONS`, `PARSERS`, `SCENARIOS`, `POSTOVERFLOWS`, `CONTEXTS` | `agent.hub.collections`, `agent.hub.parsers`, ... (lists) |
| `agent.lapiURL`, `agent.lapiHost`, `agent.lapiPort` | `lapi.externalURL` (with `lapi.enabled: false`) |
| `agent.ports` + `agent.service.ports` | `agent.extraPorts` |
| `agent.daemonsetAnnotations`, `agent.deploymentAnnotations` | `agent.annotations` |
| `agent.strategy` | `agent.updateStrategy` |
| `agent.hostVarLog` | removed: `/var/log` is mounted when `agent.podLogs` is set |
| `agent.persistentVolume.*` | removed |
| `agent.wait_for_lapi.*` | removed: the `wait-for-lapi` init container waits for LAPI. Its security context and resources are set by `helperContainers` (hardened by default) |
| `agent.metrics.*` | see LAPI |
| `agent.service.externalIPs`, ... | see LAPI |

### AppSec

| 1.x | 2.0 |
|-----|-----|
| `appsec.acquisitions` | `appsec.acquisition` (a working default is provided) |
| `appsec.configs.<file>` | `appsec.files["appsec-configs/<file>"]` |
| `appsec.rules.<file>` | `appsec.files["appsec-rules/<file>"]` |
| `appsec.scenarios.<file>` | `appsec.files["scenarios/<file>"]` |
| `appsec.postoverflows.<stage>.<file>` | `appsec.files["postoverflows/<stage>/<file>"]` |
| `appsec.env` `COLLECTIONS`, `APPSEC_CONFIGS`, `APPSEC_RULES` | `appsec.hub.collections`, `appsec.hub.appsecConfigs`, `appsec.hub.appsecRules` |
| `appsec.lapiURL`, `appsec.lapiHost`, `appsec.lapiPort` | `lapi.externalURL` (with `lapi.enabled: false`) |
| `appsec.deployAnnotations` | `appsec.annotations` |
| `appsec.strategy` | `appsec.updateStrategy` |
| `appsec.service.*` extra ports | `appsec.extraPorts` |
| `appsec.wait_for_lapi.*`, `appsec.metrics.*`, other `appsec.service.*` keys | see Agent and LAPI |

### TLS

| 1.x | 2.0 |
|-----|-----|
| `tls.enabled` | unchanged; now also implies client certificate authentication for agents and AppSec |
| `tls.agent.tlsClientAuth`, `tls.appsec.tlsClientAuth` | removed: always enabled with TLS |
| `tls.caBundle` | removed: certificate Secrets must contain `ca.crt` |
| `tls.insecureSkipVerify` | removed: set `INSECURE_SKIP_VERIFY` with `env` if you really need it |
| `tls.certManager.issuerRef`, `duration`, `renewBefore`, `secretTemplate` | unchanged |
| `tls.*.reflector.namespaces` | `tls.certManager.secretTemplate.annotations` with the reflector annotations |
| `tls.lapi.secret`, `tls.agent.secret` (without cert-manager) | `tls.existingSecrets.lapi`, `tls.existingSecrets.agent` |
| `tls.appsec.*` (AppSec server certificate) | removed: configure the AppSec listener TLS in `appsec.acquisition` and mount the certificate with `appsec.extraVolumes` |

AppSec now uses the agent client certificate (OU `agent-ou`) instead of a dedicated `appsec-ou` certificate.

## Docker runtime

Nodes using the Docker runtime through cri-dockerd write JSON logs to `/var/lib/docker/containers`. Instead of `agent.podLogs`, use:

```yaml
agent:
  acquisition:
    - source: file
      filenames:
        - /var/log/containers/my-app-*_my-namespace_*.log
      labels:
        type: docker
        program: nginx
  extraVolumes:
    - name: varlog
      hostPath: {path: /var/log}
    - name: docker-containers
      hostPath: {path: /var/lib/docker/containers}
  extraVolumeMounts:
    - {name: varlog, mountPath: /var/log, readOnly: true}
    - {name: docker-containers, mountPath: /var/lib/docker/containers, readOnly: true}
```
