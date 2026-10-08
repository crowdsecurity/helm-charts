
# TLS (manual setup)

If you don't want to use cert-manager, we provide some scripts to show how to
set up encrypted authentication and communication between agents, LAPI and
bouncers. Keep in mind that in this case, the certificate rotation when they
expire is your responsibility.

Set the following Helm values:

```yaml
tls:
  enabled: true
  certManager:
    enabled: false
  existingSecrets:
    lapi: crowdsec-lapi-tls
    agent: crowdsec-agent-tls
```

Until they exist, the agent/LAPI pods wait for the following secrets in the "crowdsec" namespace,
each containing `tls.crt`, `tls.key` and `ca.crt`:

 - crowdsec-lapi-tls: LAPI server certificate (SANs: the LAPI service name and `localhost`)
 - crowdsec-agent-tls: agent client certificate (OU `agent-ou`), also used by AppSec
 - crowdsec-bouncer-tls: bouncer client certificate (OU `bouncer-ou`), for your bouncers

If you have installed the chart with a release name other than "crowdsec", adapt `environment.sh`.

To create these, you can use the scripts in this folder.

Check if you need to change the content of `environment.sh` and run
`./deploy-all`. It will create a private CA and the certificates, sign and
upload them to the cluster. This can be done before or after installing the
helm chart. Be aware that the temporary files, including certificate keys, are left in the `tls/tmp`
directory, it's up to you to keep or delete them.

Running `./remove-all` deletes the configmap and secrets from the cluster. The temporary files are not
removed but will be overwritten if you run `./deploy-all` again.
