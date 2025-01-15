### grpc related::
## 1-grpc-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: project-grpc
  namespace: opr-develop
  labels:
    app.kubernetes.io/name: project
spec:
  type: ClusterIP
  ports:
  - name: grpc
    port: 10010
    targetPort: 10010
    protocol: TCP
  selector:
    app.kubernetes.io/name: project

## 2-grpc-gateway.yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  annotations:
    meta.helm.sh/release-name: istio-ingress
    meta.helm.sh/release-namespace: istio-system
  creationTimestamp: "2025-01-01T18:33:18Z"
  generation: 1
  labels:
    app.kubernetes.io/managed-by: Helm
  name: grpc-gateway
  namespace: istio-system
  resourceVersion: "32523426"
  uid: 55f17c19-48cd-4ac4-a2bc-3a7242d42c14
spec:
  selector:
    app: istio-ingressgateway
  servers:
  - hosts:
    - '*.kapistiogroup.com'
    port:
      name: http
      number: 8080
      protocol: HTTP
    tls:
      httpsRedirect: true
  - hosts:
    - '*.kapistiogroup.com'
    port:
      name: https
      number: 8443
      protocol: HTTPS
    tls:
      credentialName: wildcard-cert
      mode: SIMPLE
  - hosts:
    - '*.kapistiogroup.com'
    port:
      name: project-grpc  
      number: 10010       
      protocol: GRPC

## 3-grpc-vs.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  labels:
  name: grpc-vs
  namespace: opr-develop
spec:
  gateways:
  - istio-system/grpc-gateway
  hosts:
  - 'grpc.kapistiogroup.com'
  http:
  - retries:
      attempts: 3
      perTryTimeout: 2s
    match:
    - uri:
        prefix: /
    route:
      - destination:
          host: project-grpc 
          port:
            number: 10010

################# NOW MY PROJECT   ####################
## 1-project-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: project-service
  namespace: opr-develop
  labels:
    app: project-reflect-common-chart
spec:
  type: ClusterIP
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

## 2- project-vs.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: project-service
  namespace: opr-develop
spec:
  gateways:
  - istio-system/mimeo-gateway 
  hosts:
  - 'project-service.kapistiogroup.com'
  http:
  - name: api-swagger-route
    match:
    - uri:
        prefix: /api
    - uri:
        prefix: /swagger
    - uri:
        prefix: /v1
    route:
    - destination:
        host: project-service
        port:
          number: 80
  - name: grpc-route
    match:
    - uri:
        prefix: /
    route:
    - destination:
        host: project-service
        port:
          number: 10010
  - name: grpc-web-route
    match:
    - uri:
        prefix: /
    route:
    - destination:
        host: project-service
        port:
          number: 8080

