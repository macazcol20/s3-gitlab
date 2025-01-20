# Third Party Helm Charts

## ingress

https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx

This chart contains the [ingress-nginx](https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx) chart, as well
as all Reflect-specific configuration required for the deployment.

Deploy using `helm-deploy-ingress`. You can validate the changes first by running `helm-diff-ingress`.

## kube-secrets-init

https://github.com/doitintl/kube-secrets-init

Used to pull secrets from GCP Secret Manager for all Reflect Services. Deployed using `helm-deploy-kube-secrets-init`.
Changes can be validated using `helm-diff-kube-secrets-init`.

## linkerd

https://github.com/linkerd/linkerd2/tree/main/charts/linkerd2

[Linkerd](https://linkerd.io/) is a Kubernetes service mesh. In Reflect, we currently mainly use it
to improve load balancing between gRPC services.

Run `helm-deploy-linkerd` to install to the cluster.

## monitoring

https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack

Used to install Prometheus, Grafana and Alertmanager. The chart also contains custom configuration, dashboards, alerting rules, and alerting routes.
