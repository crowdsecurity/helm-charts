
# TLS

To configure certificate authentication and encrypted communication with the LAPI server, you need to set
`tls.enabled=true` in the Helm values. When the chart is installed, the creation of the agent/LAPI pods will hang while looking for
the following resources in the "crowdsec" namespace:

 - crowdsec-ca: config map containing a Certificate Authority file (ca.crt)
 - crowdsec-agent-tls: secret containing the client certificate and key files (tls.crt, tls.key)
 - crowdsec-lapi-tls: secret containing the server certificate and key files (tls.crt, tls.key)

If you have installed the chart with a release name other than "crowdsec", the resource names are `{{release}}-ca` and so on.

To create these, you can use the scripts in this folder.

Check if you need to change the content of `environment.sh` and run
`./deploy-all`. It will create a private CA and the certificates, sign and
upload them to the cluster. This can be done before or after installing the
helm chart. Be aware that the temporary files, including certificate keys, are left in the `tls/tmp`
directory, it's up to you to keep or delete them.

Running `./remove-all` deletes the configmap and secrets from the cluster. The temporary files are not
removed but will be overwritten if you run `./deploy-all` again.
