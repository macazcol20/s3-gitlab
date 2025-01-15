## for BAH
### Create GCP Artifact secret

```sh
k create ns opr-develop
```

```sh
kubectl -n opr-develop create secret docker-registry regcred-gcp \
  --docker-server=us-east1-docker.pkg.dev \
  --docker-username=_json_key \
  --docker-password="$(cat json_credentials.json)" \
  --docker-email=docker-registry-sa@unity-solutions-tyndall-prd.iam.gserviceaccount.com
```

### Create IronBank secret

```sh
# kubectl -n opr-develop create secret docker-registry regcred-ironbank \
#   --docker-server=registry1.dso.mil \
#   --docker-username=sosotechnologies \
#   --docker-password=SeqYhjqVqf8JF5jXcT8dFbVcZZdJEmeK \
#   --docker-email=cafanwi@sosotechnologies.com

kubectl -n opr-develop create secret docker-registry regcred-ironbank \
  --docker-server=registry1.dso.mil \
  --docker-username=cafanwii \
  --docker-password=zRdxM6Dy3YJCW22UzCuOERrsTJc4yzxJ \
  --docker-email=sosotech2000@gmail.com 
```

```sh
kubectl -n opr-develop create secret generic realm-secret --from-file=realm.json
```

<!-- ### Create ecr secret  --- what im using with the name regcred-gcp
```sh
kubectl create secret docker-registry regcred-gcp \
  --docker-server=440744236785.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-east-1) \
  --namespace=opr-develop \
  --docker-email=cafanwi@kapistio.com  
``` -->
<!-- 
### Create DockerHub secret
```sh
kubectl -n opr-develop create secret docker-registry regcred-gcp \
  --docker-username=cafanwii \
  --docker-password=lookatmenow20$ \
  --docker-email=afanwicollins@gmail.com
```

### Create IronBank secret

```sh
kubectl -n opr-develop create secret docker-registry regcred-ironbank \
  --docker-server=registry1.dso.mil \
  --docker-username=sosotechnologies \
  --docker-password=SeqYhjqVqf8JF5jXcT8dFbVcZZdJEmeK \
  --docker-email=cafanwi@sosotechnologies.com
```

### Create TLC secret for gateway istio-ingress

```sh
k create ns istio-system 

sudo kubectl create secret tls wildcard-cert --cert=/etc/letsencrypt/live/kapistiogroup.com/fullchain.pem --key=/etc/letsencrypt/live/kapistiogroup.com/privkey.pem -n istio-system --dry-run=client -o yaml > wildcard-cert-secret.yaml

k -n istio-system  apply -f wildcard-cert-secret.yaml
```

### Keycloak
If you are want to install keycloak. The realm.json must be added to the cluster as a secret
Note the `realm.json` in the example below assumes you are running this command from the same directory as `realm.json`

```sh
kubectl -n opr-develop create secret generic realm-secret --from-file=realm.json
``` -->
