## create ns
```sh
k create ns opr-develop
```

## Build the ingress helm chart - SKIPPED FOR NOW
```sh
cd /home/cafanwi-cap/CURRENT-WORK/bah-opr/infra/Helm/ThirdParty/ingress
helm dependency build
helm install ingress nginx . -f values.yaml -f envs/test.yaml 
```

## create persistence for postgres and rabitmq 

```sh
initdb:
    scriptsConfigMap: "db-init"
## elow is for postgres
persistence:
    enabled: true
    storageClass: "gp2"
    size: 8Gi

## aldso include this to the envs/opr-develop.yaml
storageClass: gp2
```

## sign into GCP
```sh
gcloud auth login
gcloud config set project unity-solutions-tyndall-prd  ## yes
# gcloud config set account 549448081419  ## yes
## Authenticate Docker with GCP
gcloud auth configure-docker us-east1-docker.pkg.dev          
##List Images in Artifact Registry using Service Account
gcloud auth activate-service-account --key-file=json_credentials.json  
gcloud auth list

## sign into helm registry with json key
helm registry login us-east1-docker.pkg.dev \
    --username _json_key \
    --password "$(cat json_credentials.json)"
```

## Helm dependency golia  - I can only get the 
```sh
## NOTE: This dependency can only install 3 charts : opr-keycloak-0, opr-postgresql-0, opr-rabbitmq-0 
cd /opr/infra/Helm/Reflect
helm dependency update opr
cd /opr/infra/Helm/Reflect/opr
# helm install --dry-run --debug -n opr -f ./env/opr-develop.yaml opr . > out.txt 
helm install opr -n opr-develop -f ./envs/opr-develop.yaml .

# OPTIONAL: if upgrading is required, command
helm upgrade opr . --namespace opr-develop --values values.yaml
```

## research synch
```sh
kubectl -n opr-develop logs sync-api-54c59d584f-sk2gn
kubectl -n opr-develop describe configmap sync-api-config
kubectl describe pod sync-hlodbuilder-545f5669cc-sbx58  ## no pixyz-license
kubectl -n opr-develop get secret pixyz-license
```

## The syncservice has GCP bucket references
```sh

```

## My actions, create pixyz secret from licence
[pixyz-license](https://support.unity.com/hc/en-us/articles/30730162705044-How-can-I-get-a-Pixyz-free-trial-license)

```sh
kubectl -n opr-develop create secret generic pixyz-license --from-literal=validation-key=<your-key>
```

## proxy focus
- Note: 
You can run a sidecar proxy (like Envoy, Istio's sidecar proxy, or Linkerd) as a standalone container without attaching it to another service container.
However, its behavior and functionality will differ depending on how it's configured:
A sidecar is typically deployed alongside a primary application container to augment its functionality (e.g., handling Layer 7 traffic, enabling observability, or securing communication).
When spun up as a standalone container, it operates more like a proxy or gateway.

Layer 7 (Application Layer):
Provides routing based on HTTP/HTTPS headers, paths, cookies, etc.
Enables advanced features like request transformation, load balancing, and observability.

Layer 4 (Transport Layer):
Handles raw TCP/UDP traffic.
Suitable for scenarios like mutual TLS (mTLS) between services or raw data stream forwarding.

For example:
- Envoy can be configured to act as a Layer 4 proxy (e.g., handling TCP connections) or as a Layer 7 proxy (e.g., HTTP-based traffic).
- In a service mesh context (e.g., Istio), the sidecar often performs both Layer 7 and Layer 4 functions.