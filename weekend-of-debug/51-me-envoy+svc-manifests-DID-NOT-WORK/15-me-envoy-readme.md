## encode the DB connection string

```sh
echo -n "Host=postgres;Database=ProjectService;Username=project_service;Password=reflect" | base64
```

SG9zdD1wb3N0Z3Jzc3dvcmQ9cmVmbGVjdA==

## OPTION DECODE to verify
```sh
echo "SFzc3dvcmQ9cmVmbGVjdA==" | base64 -d
```

## create GCP secret
```sh
kubectl -n project-namespace create secret docker-registry regcred \
  --docker-server=us-east1-docker.pkg.dev \
  --docker-username=_json_key \
  --docker-password="$(cat json_credentials.json)" \
  --docker-email=docker-registry-sa@unity-solutions-tyndall-prd.iam.gserviceaccount.com
```