## describe pod
```sh
kubectl -n opr-develop describe pod reflect-project-6c9d45f978-j59jb
kubectl -n opr-develop logs reflect-project-5459fbcf5f-58bqx -c project
```

## 1. Inspect the Full Logs
kubectl -n opr-develop logs reflect-project-6c9d45f978-j59jb --previous
kubectl -n opr-develop logs reflect-project-6c9d45f978-j59jb -c <container-name>

## Database Connection:
- Verify if the PostgreSQL service (opr-postgresql) is accessible from the application pod:

```sh
kubectl -n opr-develop exec -it reflect-project-6c9d45f978-j59jb -- sh
nc -zv opr-postgresql 5432
```

## Check resource limits and increase if necessary:
```sh
resources:
  limits:
    memory: "512Mi"
    cpu: "500m"
```

## Verify CoreDNS Configuration:
```sh
kubectl logs -n kube-system -l k8s-app=kube-dns
```

## lookup ns
```sh
nslookup opr-postgresql
nslookup keycloak.kapistiogroup.com
```

### My Main focus for my troubleshooting:

Because [opr-postgresql] nslookup failed:

The DNS resolver cannot resolve the name opr-postgresql. because:
opr-postgresql is not registered in the DNS service being queried.
There might be network connectivity issues between the machine and the DNS server.
The DNS server is unresponsive or misconfigured.

### current troubleshooting steps

```sh
kubectl -n opr-develop get svc
kubectl exec -it opr-postgresql-0 -n opr-develop -- nslookup opr-postgresql
kubectl exec -it opr-postgresql-0 -n opr-develop -- curl opr-postgresql:5432
```

### connect to the projectservice
```sh
kubectl -n opr-develop  exec -it opr-postgresql-0  -- psql -h opr-postgresql -U project_service -d ProjectService
```

### focus on  dns
```sh
kubectl describe configmap coredns -n kube-system

nslookup opr-postgresql.opr-develop.svc.cluster.local
kubectl get svc opr-postgresql -n opr-develop
kubectl get endpoints opr-postgresql -n opr-develop
kubectl get pods -n opr-develop -o wide
kubectl exec -it opr-postgresql-0 -n opr-develop -- /bin/sh
```

### I may have to edit the coredns to add these urls:
***KEY NOTE***
I am using (kapistiogroup.com) instead of the default cluster domain (cluster.local)

opr-postgresql
keycloak.kapistiogroup.com

based on here:  /home/cafanwii/A-opr-PTO/5-infra/Helm/Reflect/opr/README.md
```sh
kubectl edit configmap coredns -n kube-system

kubectl rollout restart deployment coredns -n kube-system

```

so instead, edit the coredns as such

```yaml
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health {
          lameduck 5s
        }
        ready
        # Rewrite the keycloak DNS name to resolve locally
        rewrite name keycloak.kapistiogroup.com opr-keycloak-http.opr-develop.svc.cluster.local
        # Rewrite other hostnames to the corresponding internal service
        rewrite name web-develop.kapistiogroup.com opr-web-service.opr-develop.svc.cluster.local
        rewrite name develop.kapistiogroup.com opr-grpc-service.opr-develop.svc.cluster.local
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
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
  labels:
    eks.amazonaws.com/component: coredns
    k8s-app: kube-dns

```

### restart and check coredns services
- The goal is for that: Your CoreDNS rewrite correctly maps keycloak.kapistiogroup.com to opr-keycloak-http.opr-develop.svc.cluster.local

```sh
kubectl -n kube-system rollout restart deployment coredns
kubectl -n kube-system get pods | grep coredns

## Test the DNS Resolution OF KEYCLOAK TO THE KEYCLOAK service IP
kubectl run -it --rm dns-test --image=busybox --restart=Never -- nslookup keycloak.kapistiogroup.com

## Test internal service DNS resolution KEYCLOAK TO THE KEYCLOAK service IP
kubectl run -it --rm dns-test --image=busybox --restart=Never -- nslookup opr-keycloak-http.opr-develop.svc.cluster.local

kubectl -n opr-develop exec -it opr-keycloak-0  -- curl -k https://localhost:8443/auth
```

### verify if  there are networkpolicies blockers
```sh
kubectl get networkpolicy -A
```

### on pod logs, I seen
```sh
An error occurred using the connection to database 'ProjectService' on server 
```

### trouble shooting while using docker exec
```sh
docker run -p 8080:80 --name project-container2 -it 440744236785.dkr.ecr.us-east-1.amazonaws.com/project:1.0.0
```

error I got:

The error message you're encountering suggests that the container is attempting to connect to a PostgreSQL database (ProjectService), but the connection is being refused:

```sql
Npgsql.NpgsqlException (0x80004005): Failed to connect to 127.0.0.1:5432
 ---> System.Net.Sockets.SocketException (111): Connection refused
```

## key discovery
- Liveness/Readiness Probes Failing:

Both probes are configured to check gRPC health (/bin/grpc_health_probe -addr=:10010) but are timing out, with crash occurs consistently after a few seconds of the container starting.

## try connecting to database  with project service:
```sh
kubectl -n opr-develop exec -it opr-postgresql-0 -- psql -h opr-postgresql -U postgres -d ProjectService
SELECT * FROM public."ApiKeys" LIMIT 20;
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';
```

## try running the container locally>
```sh
docker pull us-east1-docker.pkg.dev/unity-solutions-tyndall-prd/docker/reflect-project:develop-latest

docker run -it --rm us-east1-docker.pkg.dev/unity-solutions-tyndall-prd/docker/reflect-project:develop-latest
```

## readiness on port 127.0.0.1
```sh
helm get manifest opr -n opr-develop > template.yaml
helm get manifest opr -n opr-develop | grep -i 127.0.0.1 -A5
```

I have to Look in the Helm chart values file (or templates) for the readiness and liveness probes.
Replace the hardcoded 127.0.0.1 with the appropriate service name for PostgreSQL, which is [opr-postgresql] based my your service listing.
since the PostgreSQL instance is running in a Kubernetes pod, the host should typically be the pod's own IP or a service name that resolves to the pod's IP

```sh
kubectl get pods -n opr-develop -o wide
kubectl get services -n opr-develop
kubectl describe service opr-postgresql-hl -n opr-develop
```

update the postgres statefulset like so

```yaml
livenessProbe:
  exec:
    command:
      - /bin/sh
      - -c
      - exec pg_isready -U "postgres" -h opr-postgresql-hl -p 5432
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  successThreshold: 1
  failureThreshold: 6

readinessProbe:
  exec:
    command:
      - /bin/sh
      - -c
      - exec pg_isready -U "postgres" -h opr-postgresql-hl -p 5432
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 5
  successThreshold: 1
  failureThreshold: 6

```

