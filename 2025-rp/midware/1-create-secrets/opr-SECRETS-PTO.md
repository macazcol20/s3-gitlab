## for BAH
### Create GCP Artifact secret

```sh
k create ns middleware-dev
```

### Create IronBank secret

```sh
kubectl -n middleware-dev create secret docker-registry regcred-ironbank \
  --docker-server=registry1.dso.mil \
  --docker-username=cafanwii \
  --docker-password=zRdxM6Dy3YJCW22UzCuOERrsTJc4yzxJ \
  --docker-email=sosotech2000@gmail.com 
```

```sh
kubectl -n middleware-dev create secret generic realm-secret --from-file=realm.json
```

### Postgresql
If you are installing postgres we will need to add the db-init scripts to a configmap. 

```sh
kubectl -n opr-develop create configmap db-init --from-file=db-init/
```