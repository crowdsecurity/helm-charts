# Crowdsec WAF in kubernetes cluster

In this example, we will demonstrate how to set up Crowdsec Web Application Firewall (WAF) in a Kubernetes cluster to protect a vulnerable Wordpress installation with the in-band rules. We will also show how to write a custom rule to block specific attack vectors or specific use-cases, such as requests to the `xmlrpc.php` file in Wordpress. By the end of this guide, you will have a better understanding of how to leverage Crowdsec to enhance the security of your Kubernetes applications.

## Pre-requisites

- Working kubernetes cluster (tested on minikube)
- Ingress Nginx controller installed
- Helm installed

## Wordpress installation

```
helm install wordpress oci://registry-1.docker.io/bitnamicharts/wordpress -f wp-values.yaml
```

## Install Wordpress vulnerable plugin to CVE-2024-1071

Let get a shell in the wordpress pod and install the vulnerable plugin.

```
kubectl exec -it wordpress-7797f4d564-zp6rd -- bash
```

Then install the plugin
```
wp plugin install ultimate-member --version="2.8.2"
```

Enable the plugin in wordpress admin panel and activate the "Misc"=>"Enable custom table for usermeta" in the plugin settings.

Then use nuclei with the [following template](https://github.com/projectdiscovery/nuclei-templates/blob/4809e136ac46259452b7167c24e65e453c856b7c/http/cves/2024/CVE-2024-1071.yaml).

```
$ nuclei -u http://mywp.local:31669 -t /tmp/CVE-2024-1071.yaml 

                     __     _
   ____  __  _______/ /__  (_)
  / __ \/ / / / ___/ / _ \/ /
 / / / / /_/ / /__/ /  __/ /
/_/ /_/\__,_/\___/_/\___/_/   v3.1.7

		projectdiscovery.io

[INF] Current nuclei version: v3.1.7
[INF] Current nuclei-templates version: v10.1.0
[WRN] Scan results upload to cloud is disabled.
[INF] New templates added in latest release: 114
[INF] Templates loaded for current scan: 1
[WRN] Executing 1 unsigned templates. Use with caution.
[INF] Targets loaded for current scan: 1
[CVE-2024-1071] [http] [critical] http://mywp.local:31669/wp-admin/admin-ajax.php?action=um_get_members
```

Nuclei will return a critical vulnerability on the target.

## Crowdsec Installation

```
helm install crowdsec crowdsec/crowdsec -f crowdsec-values.yaml
```

check if all pods are running


## Setup Ingress nginx with crowdsec

patch the ingress to add crowdsec plugin
    
```
helm upgrade -n ingress-nginx ingress-nginx ingress-nginx/ingress-nginx -f ingress-nginx-values.yaml
```

## Retest the vulnerability

Thanks to the crowdsec WAF, and to the [in-band rule](https://app.crowdsec.net/hub/author/crowdsecurity/appsec-rules/vpatch-CVE-2024-1071) that blocks requests to the vulnerable endpoint, the request will be blocked.

```
$ nuclei -u http://mywp.local:31669 -t /tmp/CVE-2024-1071.yaml --debug

                     __     _
   ____  __  _______/ /__  (_)
  / __ \/ / / / ___/ / _ \/ /
 / / / / /_/ / /__/ /  __/ /
/_/ /_/\__,_/\___/_/\___/_/   v3.1.7

		projectdiscovery.io

[INF] Current nuclei version: v3.1.7
[INF] Current nuclei-templates version: v10.1.0
[WRN] Scan results upload to cloud is disabled.
[INF] New templates added in latest release: 114
[INF] Templates loaded for current scan: 1
[WRN] Executing 1 unsigned templates. Use with caution.
[INF] Targets loaded for current scan: 1
[INF] [CVE-2024-1071] Dumped HTTP request for http://mywp.local:31669/?p=1
....
[INF] [CVE-2024-1071] Dumped HTTP request for http://mywp.local:31669/wp-admin/admin-ajax.php?action=um_get_members

POST /wp-admin/admin-ajax.php?action=um_get_members HTTP/1.1
Host: mywp.local:31669
User-Agent: Mozilla/5.0 (Windows NT 5.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/35.0.3319.102 Safari/537.36
Connection: close
Content-Length: 63
Content-Type: application/x-www-form-urlencoded
Accept-Encoding: gzip

directory_id=b9238&sorting=user_login,SLEEP(5)&nonce=be737783e4
[DBG] [CVE-2024-1071] Dumped HTTP response http://mywp.local:31669/wp-admin/admin-ajax.php?action=um_get_members

HTTP/1.1 403 Forbidden
Connection: close
Transfer-Encoding: chunked
Cache-Control: no-cache
Content-Type: text/html
Date: Fri, 06 Dec 2024 13:44:14 GMT

<!DOCTYPE html>
<html lang="en">
  <head>
    <title>CrowdSec Ban</title>
    <meta content="text/html; charset=utf-8" />
....
[INF] No results found. Better luck next time!
```

Nuclei will receive a 403 error from the server, and the request will be blocked by crowdsec.

We demonstrate how the crowdsec WAF can block a critical vulnerability using virtual patching thanks to in-band rules from the crowdsec hub.
Now, we will see how to write a custom rule for a specific use case. Our example is the xmlrpc.php file in wordpress. This file is often used in brute force attacks. If users forgot to disable it, it can be a security risk. We will write a custom rule to block requests to this file.

## Write a custom rule

Following the [documentation](https://docs.crowdsec.net/docs/next/appsec/rules_syntax/), we will write a rule to block requests to xmlrpc.php.

```yaml
name: crowdsecurity/vpatch-xmlrpc
debug: true
description: "Block XMLRPC requests"
rules:
  - and:
    - zones:
        - METHOD
      match:
        type: equals
        value: POST
    - zones:
        - URI
      transform:
        - lowercase
      match:
        type: endsWith
        value: xmlrpc.php
labels:
  type: exploit
  service: http
  behavior: "http:exploit"
  label: "Block XMLRPC requests"
```

This rule will block any POST request to any URI ending with xmlrpc.php.

Now lets add this rule to crowdsec values and upgrade the helm chart.

```yaml
# upgrade-crowdsec-values.yaml
appsec:
  rules:
    mycustom-appsec-rule.yaml: |
      name: crowdsecurity/vpatch-xmlrpc
      debug: true
      description: "Block XMLRPC requests"
      rules:
        - and:
          - zones:
              - METHOD
            match:
              type: equals
              value: POST
          - zones:
              - URI
            transform:
              - lowercase
            match:
              type: endsWith
              value: xmlrpc.php
      labels:
        type: exploit
        service: http
        behavior: "http:exploit"
        label: "Block XMLRPC requests"
```

Then upgrade the helm chart

```
helm upgrade -n crowdsec crowdsec crowdsec/crowdsec -f crowdsec-values.yaml -f upgrade-crowdsec-values.yaml
```

Now, we will test the rule by sending a POST request to xmlrpc.php.

```
$ curl -XPOST http://mywp.local:31669/blog/xmlrpc.php | head
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0<!DOCTYPE html>
<html lang="en">
  <head>
    <title>CrowdSec Ban</title>
    <meta content="text/html; charset=utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
```

The request is blocked by crowdsec, and we receive a 403 error.