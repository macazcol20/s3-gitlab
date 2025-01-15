https://operator.min.io/

## 1 Install the MinIO Operator via Kustomization
```sh
kubectl create namespace minio-tenant
kubectl kustomize github.com/minio/operator\?ref=v6.0.4 | kubectl apply -f -
kubectl get pods -n minio-operator
```

<!-- ## 2 apply localStorage and PV 
```sh
## Did not use because I have longhorn already
k apply -f 1-sc.yaml
k apply -f 2-pv.yaml 
``` -->

## 3 Build the Tenant Configuration
[Link:](https://github.com/minio/operator/tree/master/examples/kustomization)

```sh
git clone https://github.com/minio/operator.git
```

## 5. Make changes to the Tenant YAML:

- To use your existing wildcard certificate stored as the secret myminio-tls in the istio-system namespace for your MinIO tenant, you need to configure your MinIO deployment to reference this external certificate secret. Here's how you can achieve that:

```sh
## update externalCertSecret 
externalCertSecret:
  - name: myminio-tls
    type: kubernetes.io/tls

## Disable Automatic Certificate Generation
requestAutoCert: false
```

## 6. DEploy the chart

```SH
cd /minio/operator/examples/kustomization/base
k apply -f .
k -n minio-tenant get po
k -n minio-tenant get svc
```

## 7. Get wildacardvalidate the secrets were created
```sh
sudo kubectl create secret tls  myminio-tls --cert=/etc/letsencrypt/live/kapistiogroup.com/fullchain.pem --key=/etc/letsencrypt/live/kapistiogroup.com/privkey.pem -n minio-tenant --dry-run=client -o yaml >  0-mymimio-tls.yaml
kubectl -n minio-tenant exec -it myminio-pool-0-0 -- ls /tmp/certs/CAs
```

## 4 expose with VS

<!-- ```sh
### NOT USING AS OF 01/15/25
## get the tls for thr dns
sudo kubectl create secret tls  myminio-tls --cert=/etc/letsencrypt/live/kapistiogroup.com/fullchain.pem --key=/etc/letsencrypt/live/kapistiogroup.com/privkey.pem -n istio-system --dry-run=client -o yaml >  myminio-tls.yaml

## Get the tls that came with minio-tenant. / updatethe .key and .crt with your tls secret
k -n minio-tenant get secret myminio-tls -o yaml > minio-tls.yaml
## reapply the secret with updated values
k apply -f minio-tls.yaml

kubectl get endpoints minio -n minio-tenant

``` -->

## Now create the gateway and vs
```sh

```

## Access via MinIO Client (MC):
```sh
kubectl -n minio-tenant describe secret myminio-tls
kubectl -n minio-tenant get secret myminio-tls -o jsonpath='{.data.public\.crt}' | base64 --decode > public.crt

openssl x509 -in public.crt -text -noout

mc alias set myminio https://10.0.0.88 console console123
mc admin info myminio
```

