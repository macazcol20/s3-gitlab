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

## Other findings --- It's using nodeport service in the following files
- search in code:  [  targetPort: 10010 ]

```yaml
## prokectservice port and nodeport issue

## \project\4-project-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: project-service
  namespace: opr-develop
  labels:
    app: project-reflect-common-chart
spec:
  ports:
    - name: prom-publisher
      protocol: TCP
      port: 1234
      targetPort: 1234
    - name: grpc
      protocol: TCP
      port: 10010
      targetPort: 10010
    - name: grpc-web
      protocol: TCP
      port: 8080
      targetPort: 8080
    - name: http
      protocol: TCP
      port: 80
      targetPort: 80
  selector:
    app: project-reflect-common-chart

## 5-infra\Helm\Reflect\project\values.yaml
service:
    enabled: true
    ports:
      - name: prom-publisher
        protocol: TCP
        port: 1234
      - name: grpc
        protocol: TCP
        port: 10010
        targetPort: 10010
      - name: grpc-web
        protocol: TCP
        port: 8080
        targetPort: 8080
      - name: http
        protocol: TCP
        port: 80
        targetPort: 80
      - name: grpc-web-admin
        protocol: TCP
        port: 9901
        targetPort: 9901
  serviceMonitor:

## 5-infra\Helm\Reflect\project-grpc-nodeport\values.yaml
reflect-common-chart:
  fullnameOverride: "project-grpc"
  service:
    enabled: true
    selectorLabel:
      app.kubernetes.io/name: project
    type: NodePort
    ports:
      - name: project-grpc
        protocol: TCP
        port: 10010
        targetPort: 10010
        nodePort: 30010

```

## Also NOTE 
in the C:\Users\macazcol\Desktop\cafanwii\A-opr-PTO\5-infra\Helm\Reflect\postgres-integration-svc\values.yaml

the service-file is defined as Nodeport

```yaml
reflect-common-chart:
  fullnameOverride: "postgres-integration-svc"
  service:
    enabled: true
    selectorLabel: 
      app.kubernetes.io/name: postgresql
      app.kubernetes.io/component: primary
    type: NodePort
    ports:
      - name: postrgres-integration-test-svc
        protocol: TCP
        port: 5432
        targetPort: 5432
        nodePort: 30432
```

### 01/25
Key Observations
project Service (ClusterIP):

Exposes multiple ports, including:
prom-publisher (1234)
grpc (10010)
grpc-web (8080)
http (80)
grpc-web-admin (9901)
The application logs confirm it listens on http://[::]:80 and starts the Prometheus exporter on port 1234.
postgres-integration-svc Service (NodePort):

Exposes port 5432 (PostgreSQL) internally and externally via NodePort at 30432.
project-grpc Service (NodePort):

Maps the GRPC port 10010 to external NodePort 30010.
Likely Issue:

The ProjectService logs show database connection failures (Name or service not known). This could mean:
The postgres-integration-svc is unreachable.
The database hostname in the connection string does not match the Kubernetes service name (postgres-integration-svc).

logs indicate a failure to connect to the database, which could be due to:
Network Policies: Restricting traffic between ProjectService and opr-postgresql.
Service Misconfiguration: Double-check the NodePort exposure and ensure internal connectivity works.

```sh
kubectl exec -n opr-develop -it project-55b6775c45-rzp95 -- curl -v http://project:1234
kubectl exec -n opr-develop -it opr-keycloak-0 -- curl -v http://opr-keycloak-http:80
kubectl exec -n opr-develop -it project-55b6775c45-rzp95 -- nslookup postgres-integration-svc
kubectl get networkpolicy -n opr-develop
kubectl logs -n opr-develop project-55b6775c45-rzp95
kubectl exec -n opr-develop -it project-55b6775c45-rzp95 -- env # [Ensure DB_HOST=opr-postgresql, DB_PORT=5432, and other values align with the working connection.]

kubectl -n opr-develop  exec -it opr-postgresql-0  -- psql -h opr-postgresql -U project_service -d ProjectService 
``




