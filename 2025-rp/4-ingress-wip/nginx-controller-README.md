## after applying teraform

### update dependency 
```sh
k create ns  monitoring
# helm dependency build
```

## NOTES:  
- Make sure to update secrets-manager role that was created with OpenTofu [role] in  envs/prd.yaml - certManager.issuer.awsIAMRole
- Also update the nodegroup selector to your nodegroup in envs/prd.yaml
- Make sure to update the Route 53 Hosted Zone ID [hostedZoneID] in /templates/letsencrypt-clusterissuer.yaml --> you can get the hostedZone ID with 

```sh
aws route53 list-hosted-zones --query "HostedZones[?Id=='/hostedzone/Z003045025KEQUS78IRZI']"
```


### verify DNS records
```sh
dig +short TXT _acme-challenge.kapistiogroup.com
dig +short NS kapistiogroup.com
```

### optional, output yaml
```sh
helm upgrade --install ingress ./ -f values.yaml -f envs/prd.yaml --dry-run > my-ingress.yaml
```

### Install chart
```sh
helm upgrade --install ingress ./ -f values.yaml -f envs/prd.yaml
```

### commands to verify objects were created
```sh
kubectl get certificates -A   # If you see ready [True], you're good
kubectl get clusterissuers
kubectl get orders -A ## if you see state [valid], then you are good  valid 
kubectl get issuer   # namespace-scope, not important
kubectl describe certificate tls -n default

kubectl describe certificate monitoring-tls -n monitoring
kubectl get challenges.acme.cert-manager.io
kubectl logs -n cert-manager deploy/cert-manager
kubectl logs -l app=cert-manager -n cert-manager
kubectl describe certificaterequest reflect-tls -n default
kubectl describe certificaterequest monitoring-tls-1 -n monitoring
kubectl describe clusterissuer reflect-letsencrypt-issuer

kubectl get challenges -A
```

If you see ready [True]

<!-- # install crd for nginx
[link:](https://github.com/kubernetes/ingress-nginx/tree/main/deploy/static/provider/aws)

## get the vpc ID and update thhis ip to the proxy in deploy.yaml
```sh
aws ec2 describe-vpcs --vpc-ids vpc-0549b7246ac011481 --query "Vpcs[0].CidrBlock"    ### and update thhis ip to the proxy in deploy.yaml
```

## deploy the chart
```sh
kubectl create namespace monitoring
curl -O https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/aws/nlb-with-tls-termination/deploy.yaml
less deploy.yaml
kubectl apply -f deploy.yaml
kubectl get crds | grep ingress
kubectl get crds | grep -E 'ingress|cert-manager|policy|autoscaling|monitoring'
```

```sh
k -n ingress-nginx get deploy
k -n ingress-nginx get po
kubectl logs ingress-nginx-controller-5d56d556cc-682qj -n ingress-nginx
kubectl exec -it ingress-nginx-controller-5d56d556cc-682qj -n ingress-nginx -- cat /etc/nginx/nginx.conf

aws elb describe-load-balancers
aws elbv2 describe-load-balancers
```

### AFTER DEPLOYING

<!-- 
Key parts of the configuration you might want to highlight:

1. Worker Settings:
The number of worker processes is set to 2.
Maximum number of open files per worker is set to 1,047,552.
Other performance-related settings such as worker_connections, aio, and tcp_nodelay are configured for better throughput.

2. SSL Configuration:
SSL is enabled with protocols TLSv1.2 and TLSv1.3.
Custom SSL cipher suites are defined.
The SSL certificate and key are pointing to a default fake certificate.

3. Logging:
Custom log formats are set for both access and error logs.
Access logs are filtered using Lua scripts, and error logs are written with a notice level.
Logging is set up to exclude certain HTTP requests and only log certain types based on the $loggable variable.

4. HTTP and Proxy Settings:
Configurations for handling requests such as setting headers like X-Forwarded-For and X-Real-IP.
Connection management settings such as timeouts, proxy buffering, and connection reuse are specified.
There are custom locations for health checks, such as /healthz, and status checks on /nginx_status.

5. Load Balancing:
The upstream block uses Lua scripting for dynamic backend management, which can help distribute requests across backend servers.

6. Health Checks:
Health check endpoints like /healthz return a 200 status for successful checks.
Monitoring for internal endpoints such as /nginx_status. 
-->

<!-- ### to Enable mTLS in the NGINX
I will have to add the following directives to your nginx.conf file under the appropriate server block:

#####
```yaml
ssl_verify_client on;
ssl_client_certificate /path/to/ca_certificate.crt;
```

## cert manager crds
```sh
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml
```

## cert prometheus-operator
```sh
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
``` --> 

## my deleted text record


## my deleted text record

jT5BilNgdS3_tcZHYBsyy2EZhPeAVIXvF1rWZffzQvg