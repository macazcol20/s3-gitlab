Investigate what Envoy Do in This Context?

Ingress or API Gateway: Handles HTTP/HTTPS requests, including SSL termination, authentication, or routing.
gRPC Proxy: Since your project container uses gRPC (10010), Envoy might manage gRPC traffic, load balancing, or protocol translation (e.g., HTTP/1 to HTTP/2).

```sh
kubectl logs project-55b6775c45-rqksj -n opr-develop -c envoy
```

## see current envoy yaml
```sh
kubectl -n opr-develop  exec -it project-55b6775c45-rqksj -- /bin/sh
kubectl cp opr-develop/project-55b6775c45-rqksj:etc/envoy/envoy.yaml ./envoy.yaml -c envoy
```


## get the envoy on url
```sh
kubectl port-forward pod/project-55b6775c45-rqksj 9901:9901 -n opr-develop

curl http://127.0.0.1:9901
curl http://127.0.0.1:9901/stats
curl http://127.0.0.1:9901/config_dump
curl http://127.0.0.1:9901/clusters
curl http://127.0.0.1:9901/listeners
curl http://127.0.0.1:9901/server_info
curl http://127.0.0.1:9901/memory
curl http://127.0.0.1:9901/runtime
curl http://127.0.0.1:9901/stats/prometheus
```

currently my envoy is listening in port 80 http... I want to change to  https with these steps:

```sh
## Deploying Envoy on HTTPS in EKS
## TLS-settings.yaml
static_resources:
  listeners:
    - name: listener_0
      address:
        socket_address: { address: 0.0.0.0, port_value: 443 }
      filter_chains:
        - filters:
            - name: envoy.filters.network.http_connection_manager
              config:
                codec_type: AUTO
                stat_prefix: ingress_http
                route_config:
                  name: local_route
                  virtual_hosts:
                    - name: backend
                      domains: ["*"]
                      routes:
                        - match: { prefix: "/" }
                          route: { cluster: backend_cluster }
                http_filters:
                  - name: envoy.filters.http.router
        transport_socket:
          name: envoy.transport_sockets.tls
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext
            common_tls_context:
              tls_certificates:
                - certificate_chain: { filename: "/etc/envoy/certs/cert.pem" }
                  private_key: { filename: "/etc/envoy/certs/key.pem" }
```

## deployment
```sh
## Deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: envoy
  labels:
    app: envoy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: envoy
  template:
    metadata:
      labels:
        app: envoy
    spec:
      containers:
        - name: envoy
          image: envoyproxy/envoy:vX.X.X
          ports:
            - containerPort: 443
          volumeMounts:
            - name: certs
              mountPath: /etc/envoy/certs
            - name: config
              mountPath: /etc/envoy
          args:
            - --config-path
            - /etc/envoy/envoy.yaml
      volumes:
        - name: certs
          secret:
            secretName: envoy-certs
        - name: config
          configMap:
            name: envoy-config
```

```sh
## service.yaml
apiVersion: v1
kind: Service
metadata:
  name: envoy
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "https"
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "<YOUR_CERT_ARN>"
    service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
spec:
  type: LoadBalancer
  ports:
    - port: 443
      targetPort: 443
      protocol: TCP
  selector:
    app: envoy
```

## Certificates for HTTPS
```sh
kubectl create secret tls envoy-certs \
  --cert=cert.pem \
  --key=key.pem
```
