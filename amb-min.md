## Ambient
https://istio.io/latest/docs/ambient/getting-started/secure-and-visualize/

```sh
kubectl label namespace default istio.io/dataplane-mode=ambient
```

## Visualize the application and metrics
```sh
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/kiali.yaml

istioctl dashboard kiali

## Let’s send some traffic to the Bookinfo application, so Kiali generates the traffic graph:
for i in $(seq 1 100); do curl -sSI -o /dev/null https://longhorn.kapistiogroup.com; done
```

## minio client
[all yamls](https://repo1.dso.mil/big-bang/bigbang/-/blob/master/chart/values.yaml)

##  minioOperator:
    git:
      repo: https://repo1.dso.mil/big-bang/product/packages/minio-operator.git
      path: "./chart"
      tag: "6.0.4-bb.1"
    helmRepo:
      repoName: "registry1"
      chartName: "minio-operator"
      tag: "6.0.4-bb.1"

##  minio:
    git:
      repo: https://repo1.dso.mil/big-bang/product/packages/minio.git
      path: "./chart"
      tag: "6.0.4-bb.5"
    helmRepo:
      repoName: "registry1"
      chartName: "minio-instance"
      tag: "6.0.4-bb.5"

## NOTE TO SELF
- Minio-operator bigbang did not work, so commented the sections out
- using the community mimio operator


```sh
kubectl create ns minio-operator
kubectl create ns minio 
```

## Install minio-operator - community
```sh
https://operator.min.io/

## 1 Install the MinIO Operator via Kustomization
```sh
kubectl kustomize github.com/minio/operator\?ref=v6.0.4 | kubectl apply -f -
kubectl get pods -n minio-operator
```

## create a secret of your token-CLI secret
```sh
# kubectl -n minio-operator create secret docker-registry private-registry \
#   --docker-server=registry1.dso.mil \
#   --docker-username=cafanwii \
#   --docker-password=zRdxM6Dy3YJCW22UzCuOERrsTJc4yzxJ \
#   --docker-email=sosotech2000@gmail.com 

kubectl -n minio create secret docker-registry private-registry \
  --docker-server=registry1.dso.mil \
  --docker-username=cafanwii \
  --docker-password=zRdxM6Dy3YJCW22UzCuOERrsTJc4yzxJ \
  --docker-email=sosotech2000@gmail.com 
```

## clone the chart minio-operator then minio chart

```sh
# git clone  https://repo1.dso.mil/big-bang/product/packages/minio-operator.git
git clone https://repo1.dso.mil/big-bang/product/packages/minio.git
```

## nexT: Cd into the chart and install Istio
<!-- 
```sh
mv minio-operator io
cd io 
mv chart minio-operator
mv minio-operator ../
cd ..
rm -rf io
``` -->

```sh
mv minio ic
cd ic
mv chart minio
mv minio ../
cd ..
rm -rf ic
```

<!-- ### install minio-operator
```sh
helm -n minio-operator install minio-operator minio-operator/
k -n minio-operator get po 
k -n minio-operator get svc
``` -->

### install minio-system
```sh
helm -n minio install minio minio/
```

### edit this service to Loadbalancer, for now... istio VS will be used in prod

```sh
k edit svc minio-minio-instance-console -n minio
```

### get the secrets to login
```sh
kubectl get secret minio-creds-secret -n minio -o jsonpath='{.data.accesskey}' | base64 --decode && echo
kubectl get secret minio-creds-secret -n minio -o jsonpath='{.data.secretkey}' | base64 --decode && echo
```

### implement vs
```sh
## create the virtualservice
k apply -f minio-vs.yaml
```


## Install MinIO Client (mc)
[https://min.io/docs/minio/linux/reference/minio-mc-admin.html](https://min.io/docs/minio/linux/reference/minio-mc-admin.html)

```sh
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o $HOME/minio-binaries/mc

chmod +x $HOME/minio-binaries/mc
export PATH=$PATH:$HOME/minio-binaries/

mc --help
```

## use minio
```sh
mc alias set myminio https://minio-instance.kapistiogroup.com minio minio123
mc mb myminio/sync-service-dev
mc ls myminio
```

## retention and worn policy
<!-- ```sh
mc retention get myminio/sync-service-dev
## Disable Retention for a Specific Object:
mc retention unset myminio/sync-service-dev/<object-name>
## Disable Retention for a Specific Object:
mc find myminio/sync-service-dev --exec "mc retention unset myminio/sync-service-dev/{}"

## NEXT:
## Check WORM Protection
mc admin config get myminio/ worm
## Disable WORM Mode Temporarily: If WORM is enabled and you want to disable it, run:
mc admin config set myminio/ worm=off
mc admin service restart myminio
``` -->
```sh
mc stat myminio/sync-service-dev/
mc stat myminio/sync-service-dev/startup-test
```

## Deleting a bucket
```sh
## delete by day
mc rm --recursive --force --older-than 1d myminio/sync-service-dev
## delete by hour
mc rm --recursive --force --older-than 1h myminio/sync-service-dev
## delete by minutes
mc rm --recursive --force --older-than 30m myminio/sync-service-dev

## Delete All Objects in the Bucket
mc rm --recursive --force myminio/sync-service-dev

## remove all incomplete or partially uploaded objects
mc rm --recursive --incomplete --force myminio/sync-service-dev

## Delete Objects Matching a Specific Pattern
mc rm --recursive --force myminio/sync-service-dev/prefix-*
## - Example: Delete all .log files:
mc rm --recursive --force myminio/sync-service-dev/*.log

## Delete the Entire Bucket
mc rb --force myminio/sync-service-dev
```


```sh
## if no access, deploy a minio pod for cli
- Deploy a Permanent Pod (Reusable)

```sh
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: minio-client
  namespace: minio
spec:
  containers:
  - name: minio-client
    image: minio/mc
    command: ["/bin/sh", "-c", "while true; do sleep 3600; done"]
EOF

```

```sh
kubectl exec -it minio-client -n minio -- /bin/sh
```

```sh
mc alias set myminio http://minio-minio-instance-hl.minio.svc.cluster.local:9000 minio minio123
```

```sh
mc mb myminio/collins-opr-dev
```
