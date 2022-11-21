#!/bin/sh

[ -z "$RELEASE" ] && RELEASE=crowdsec
[ -z "$NAMESPACE" ] && NAMESPACE=crowdsec

export NAME_CA=$RELEASE-ca
export NAME_LAPI_SERVICE=$RELEASE-service
export NAME_LAPI_CSR=$NAME_LAPI_SERVICE.$NAMESPACE
export NAME_AGENT_CSR=$RELEASE-agent.$NAMESPACE
export NAME_LAPI_SECRET=$RELEASE-lapi-tls
export NAME_AGENT_SECRET=$RELEASE-agent-tls

export SIGNER_NAME=crowdsec.net/signing
export LAPI_DNS=$NAME_LAPI_SERVICE.$NAMESPACE

