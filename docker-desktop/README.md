## OPR
This chart is mean to be an umbrella chart. `Chart.yaml` will include the sub-charts installed by the OPR chart. Some of the infrastructure charts can be enabled disbaled in the `values.yaml` file under the `infra` tag. 

```
infra:
  postgresql: true
  keycloak: true
  rabbitmq: true
```
Additionally, for integration testing purposes we make some services available using nodeports. 
We have them set as false in our default values since these should **never be used in production**. They can be set to true if you would like to expose nodeports without using ingress.  
```
  project-grpc-nodeport: false
  postgres-integration-svc: false

```

## Prerequisites
### Keycloak
If you are want to install keycloak. The realm.json must be added to the cluster as a secret
Note the `realm.json` in the example below assumes you are running this command from the same directory as `realm.json`

`kubectl -n opr-develop create secret generic realm-secret --from-file=realm.json`

### Postgresql
If you are installing postgres we will need to add the db-init scripts to a configmap. 

`kubectl -n opr-develop create configmap db-init --from-file=db-init/`

This will add all the files in the `db-init/` directory to the configmap that will be mounted into the `docker-entrypoint-initdb.d` directory inside the container which will be executed on first boot. 



## Ingress
This chart assumes ingress-nginx is installed in the cluster. 
Currently there are 3 or 4 required ingress endpoints depending on if keycloak is installed. 
1. project-service grpc-web port -> This endpoint is directed to the envoy sidecar container in the project-service pod
2. project service grpc port -> This endpoint is directed to the grpc port of project service 
3. project service http port -> This endpoint is directed to the http port of project service. It shares the same hostname as the grpc port but the path determines the routing. 
4. (optional) keycloak http port -> This endpoint of the keycloak installation if installed in the as part of this chart. If infra.keycloak is set to false, it will not be installed or used.

## Docker images
The serialized docker images that are provided in in the `images` directory need to be pushed to a registry before proceeding with the installation of the OPR helm chart.

`kubectl -n opr-develop create secret docker-registry regcred-opr --docker-server=PRIVATE_REGISTRY_URL --docker-username=PRIVATE_REGISTRY_USER --docker-password=PRIVATE_REGISTRY_PASSWORD`

The default values in this chart also reference some images in the ironbank registry which would need to be added to the kubernetes secrets as well 

`kubectl -n opr-develop create secret docker-registry regcred-ironbank --docker-server=registry1.dso.mil --docker-username=IRONBANK_USER --docker-password=PASSWORD`

## Installation
 
If you've confirmed all the prerequisites are inplace, its recommended you make a copy of the values file and modify it to suit your environment.

A few notable values to be aware of are the `imagePullSecrets`. They should be the registry credentials in the above step.

The image repository urls should reflect the registry in which the images have been pushed to. 

2 or, if keycloak was installed, 3 resolvable hostnames will need to be configured as well. 

grpc-web -> ex: web-develop.unity.opr.com 
grpc/http -> ex: develop.unity.opr.com
keycloak (optional) -> ex: keycloak-develop.unity.opr.com

The values also contains configmaps for environment variables that start with  `REFLECTPROJECT_Security__OnPrem`. The default values for some will need to be modified with the correct keycloak URL. 

The chart can then be installed into the same namespace as the secrets in the previous steps were created. 

## Keycloak DNS for dev environments
In the case where your keycloak deployment is inside the cluster. As is the case with some dev environments. We might want to add an alias in core DNS so that the hostname resolves to a cluster IP instead of a public one. This is mostly likely only required using during local development. 

We do this by modifying the configmap of coreDNS  

`kubectl -n kube-system edit cm coredns`

We want to add a rewrite rule. for example:
```
rewrite name unity.keycloak.local opr-keycloak-http.opr-develop.svc.cluster.local
```
Instead of leaving the cluster to check for the DNS of  `unity.keycloak.local` it will return the local IP of our keycloak service. 

We can also do this for the nignx ingress service if prefered. 

The full config should look similar to 
```
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        rewrite name unity.keycloak.local opr-keycloak-http.opr-develop.svc.cluster.local
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
```
