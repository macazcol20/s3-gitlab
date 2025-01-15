https://github.com/kubernetes/ingress-nginx

## prerequisites
- install any webapp service, In my example I have a keycloak service already
- save the ingress load balancer ip as a wildcard A record: A   |  *  | 10.0.0.19

```sh
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm search repo ingress-nginx --versions

kubectl create namespace ingress-nginx


CHART_VERSION="4.10.1"
APP_VERSION="1.10.1"

helm template ingress-nginx ingress-nginx  \
--repo https://kubernetes.github.io/ingress-nginx \
--version ${CHART_VERSION} \
--namespace ingress-nginx \
> ./nginx-ingress.${APP_VERSION}.yaml

k apply -f ./nginx-ingress.${APP_VERSION}.yaml
kubectl get pods -n ingress-nginx
kubectl -n ingress-nginx get svc 
kubectl get services -o wide -w --namespace ingress-nginx
```