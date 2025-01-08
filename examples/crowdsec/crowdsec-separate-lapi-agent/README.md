# Crowdsec Separate installation LAPI and Agent (Log processor)

This example shows how to install Crowdsec with a separate LAPI and Agent. The LAPI is the API server that receives signals from the agents and the agents are the log processors that analyze the logs and send signals to the LAPI.

## Pre-requisites

- Working kubernetes cluster (tested on minikube)
- Helm installed

## Install Crowdsec as Local API (LAPI)

```bash
helm install crowdsec crowdsec/crowdsec -f crowdsec-lapi-values.yaml -n crowdsec-lapi --create-namespace
```

## Install Crowdsec Agent

For testing we install the agent in the default namespace.

```bash
helm install crowdsec-agent crowdsec/crowdsec -f crowdsec-agent-values.yaml
```

## Check if all pods are running

Check if the LAPI is running:

```bash
kubectl get pods -n crowdsec-lapi

NAME                             READY   STATUS    RESTARTS   AGE
crowdsec-lapi-77d9d768b9-482m7   1/1     Running   0          20m
```

Check if the agent is running:

```bash
kubectl get pods

NAME                   READY   STATUS    RESTARTS   AGE
crowdsec-agent-gqd85   1/1     Running   0          7m12s
```

We can also check if the agent is properly registered with the LAPI:

```bash
kubectl exec -it crowdsec-lapi-77d9d768b9-482m7 -n crowdsec-lapi -- cscli machines list

──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
 Name                            IP Address    Last Update           Status  Version          OS                            Auth Type  Last Heartbeat 
──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
 crowdsec-lapi-77d9d768b9-482m7                2025-01-08T14:04:48Z  ✔️                       ?                             password   ⚠️ -               
 crowdsec-agent-gqd85            10.244.0.102  2025-01-08T14:26:09Z  ✔️      v1.6.4-523164f6  Alpine Linux (docker)/3.20.3  password   56s            
──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

```