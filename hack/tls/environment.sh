#!/bin/sh

export NAMESPACE=crowdsec
export NAME_CA=crowdsec-ca
export NAME_LAPI_SERVICE=crowdsec-service
export NAME_LAPI_CSR=$NAME_LAPI_SERVICE.$NAMESPACE
export NAME_AGENT_CSR=crowdsec-agent.$NAMESPACE
export NAME_LAPI_SECRET=crowdsec-lapi-tls
export NAME_AGENT_SECRET=crowdsec-agent-tls

export SIGNER_NAME=crowdsec.net/signing
export LAPI_DNS=$NAME_LAPI_SERVICE.$NAMESPACE

