#!/usr/bin/env python3
"""Generates charts/crowdsec/values.schema.json. Run: python3 hack/crowdsec-values-schema.py > charts/crowdsec/values.schema.json"""
import json, sys

def obj(props, required=None, desc=None):
    o = {"type": "object", "additionalProperties": False, "properties": props}
    if required: o["required"] = required
    if desc: o["description"] = desc
    return o

S = lambda d=None: {"type": "string", **({"description": d} if d else {})}
B = lambda d=None: {"type": "boolean", **({"description": d} if d else {})}
I = lambda mn=0: {"type": "integer", "minimum": mn}
MAP = {"type": "object", "additionalProperties": {"type": "string"}}
ANYOBJ = {"type": "object"}
ARR = {"type": "array"}
OBJARR = {"type": "array", "items": {"type": "object"}}
FILES = {"type": "object", "additionalProperties": {"type": "string"},
         "description": "Files written under /etc/crowdsec: key is the relative path, value the content"}

def service(with_port=False):
    p = {"type": {"type": "string", "enum": ["ClusterIP", "NodePort", "LoadBalancer"]},
         "annotations": MAP, "labels": MAP,
         "internalTrafficPolicy": {"type": "string", "enum": ["", "Cluster", "Local"]},
         "trafficDistribution": S(),
         "nodePorts": {"type": "object", "additionalProperties": {"type": "integer", "minimum": 1, "maximum": 65535}},
         "extraSpec": {"type": "object", "description": "Extra Service spec fields (not type, selector, ports)"}}
    if with_port: p["port"] = I(1)
    return obj(p)

metrics = obj({"serviceMonitor": obj({"enabled": B(), "labels": MAP, "interval": S(), "scrapeTimeout": S(),
                                      "honorLabels": B(), "relabelings": OBJARR, "metricRelabelings": OBJARR})})
pdb = obj({"enabled": B(), "maxUnavailable": {"type": ["integer", "string"]}})

def hub(keys):
    return obj({k: {"type": "array", "items": {"type": "string"}} for k in keys})

pod_common = {
    "config": {"type": "object", "description": "Merged into config.yaml.local"},
    "files": FILES,
    "env": OBJARR, "envFrom": OBJARR,
    "metrics": metrics,
    "resources": ANYOBJ,
    "livenessProbe": ANYOBJ, "readinessProbe": ANYOBJ, "startupProbe": ANYOBJ,
    "annotations": MAP, "podLabels": MAP, "podAnnotations": MAP,
    "podSecurityContext": ANYOBJ, "securityContext": ANYOBJ,
    "serviceAccountName": S(), "priorityClassName": S(),
    "nodeSelector": MAP, "tolerations": OBJARR, "affinity": ANYOBJ,
    "topologySpreadConstraints": OBJARR,
    "extraInitContainers": OBJARR, "extraVolumes": OBJARR, "extraVolumeMounts": OBJARR,
    "extraContainers": OBJARR,
    # Free-form: any Kubernetes field, validated by the API server (fields built by the chart are refused in validate.yaml)
    "podSpec": ANYOBJ, "containerSpec": ANYOBJ, "workloadSpec": ANYOBJ,
}

lapi = obj({**pod_common,
    "enabled": B(), "externalURL": S("LAPI URL used by agents when lapi.enabled is false"),
    "replicas": I(1),
    "database": obj({
        "type": {"type": "string", "enum": ["postgresql", "mysql"]},
        "host": S(), "port": {"type": ["integer", "null"], "minimum": 1, "maximum": 65535},
        "name": S(), "user": S(), "sslMode": S(),
        "existingSecret": S(), "passwordKey": S()}),
    "onlineAPI": obj({"enabled": B(), "existingSecret": S(),
        "registrationJob": obj({"image": obj({"registry": S(), "repository": S(), "tag": S(), "digest": S(),
            "pullPolicy": {"type": "string", "enum": ["Always", "IfNotPresent", "Never"]}}),
            "podLabels": MAP, "podAnnotations": MAP})}),
    "console": obj({"enrollKey": S(), "instanceName": S(), "tags": {"type": "array", "items": {"type": "string"}}}),
    "service": service(with_port=True),
    "ingress": obj({"enabled": B(), "className": S(), "annotations": MAP, "host": S(), "tls": OBJARR}),
    "podDisruptionBudget": pdb,
    "strategy": ANYOBJ,
})

port = obj({"name": {"type": "string", "maxLength": 15}, "port": I(1),
            "protocol": {"type": "string", "enum": ["TCP", "UDP"]}}, required=["name", "port"])
podlog = obj({"namespace": S(), "pod": S(), "program": S()}, required=["namespace", "pod", "program"])

agent = obj({**pod_common,
    "enabled": B(), "kind": {"type": "string", "enum": ["DaemonSet", "Deployment"]},
    "replicas": I(1),
    "hub": hub(["collections", "parsers", "scenarios", "postoverflows", "contexts"]),
    "podLogs": {"type": "array", "items": podlog},
    "acquisition": OBJARR,
    "extraPorts": {"type": "array", "items": port},
    "service": service(),
    "updateStrategy": ANYOBJ,
})

appsec = obj({**pod_common,
    "enabled": B(), "kind": {"type": "string", "enum": ["DaemonSet", "Deployment"]},
    "replicas": I(1), "port": I(1),
    "hub": hub(["collections", "scenarios", "postoverflows", "appsecConfigs", "appsecRules"]),
    "acquisition": OBJARR,
    "extraPorts": {"type": "array", "items": port},
    "service": service(),
    "podDisruptionBudget": pdb,
    "updateStrategy": ANYOBJ,
})

schema = {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "title": "CrowdSec Helm chart values",
    **obj({
        "global": ANYOBJ,
        "nameOverride": S(), "fullnameOverride": S(), "commonLabels": MAP, "commonAnnotations": MAP,
        "imageRegistry": S(),
        "helperContainers": obj({"securityContext": ANYOBJ, "resources": ANYOBJ}),
        "extraObjects": {"type": "array", "items": {"type": ["object", "string"]}},
        "image": obj({"registry": S(), "repository": S(), "tag": S(), "digest": S(),
                      "pullPolicy": {"type": "string", "enum": ["Always", "IfNotPresent", "Never"]}}),
        "imagePullSecrets": OBJARR,
        "podLabels": MAP, "podAnnotations": MAP,
        "auth": obj({"existingSecret": S()}),
        "tls": obj({"enabled": B(),
            "certManager": obj({"enabled": B(), "issuerRef": obj({"name": S(), "kind": S(), "group": S()}),
                "duration": S(), "renewBefore": S(), "secretTemplate": obj({"annotations": MAP, "labels": MAP})}),
            "existingSecrets": obj({"lapi": S(), "agent": S()})}),
        "lapi": lapi, "agent": agent, "appsec": appsec,
    }),
}
json.dump(schema, sys.stdout, indent=2)
print()
