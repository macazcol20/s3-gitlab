
### Postgresql
If you are installing postgres we will need to add the db-init scripts to a configmap. 

```sh
kubectl -n opr-develop create configmap db-init --from-file=db-init/
```