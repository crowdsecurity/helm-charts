#!/bin/sh

[ -z "$RELEASE" ] && RELEASE=crowdsec
[ -z "$NAMESPACE" ] && NAMESPACE=crowdsec

export NAME_CA=$RELEASE-ca
# Service name of the chart (<fullname>-lapi). Adjust if the release name does not contain "crowdsec".
export NAME_LAPI_SERVICE=$RELEASE-lapi
export NAME_LAPI_CSR=$NAME_LAPI_SERVICE.$NAMESPACE
export NAME_AGENT_CSR=$RELEASE-agent.$NAMESPACE
export NAME_BOUNCER_CSR=$RELEASE-bouncer.$NAMESPACE
export NAME_LAPI_SECRET=$RELEASE-lapi-tls
export NAME_AGENT_SECRET=$RELEASE-agent-tls
export NAME_BOUNCER_SECRET=$RELEASE-bouncer-tls

export SIGNER_NAME=crowdsec.net/signing
export LAPI_DNS=$NAME_LAPI_SERVICE.$NAMESPACE

