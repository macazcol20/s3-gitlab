## Added to upstream chart to support istio
hostname: s3gis.be

istio:
  # Toggle istio interaction
  enabled: true
  envoy:
    enabled: true
    annotations: {}
    labels: {}
    gateways:
      - istio-system/mimeo-gateway
    hosts:
      - host.{{ .Values.hostname }}
## End of addition

# replicaCount -- number of replicas for haproxy deployment.
replicaCount: 1

image:
  # image.repository -- image repository
  repository: registry1.dso.mil/ironbank/opensource/istio-1.7/proxyv2-1.7
  # image.tag -- image tag (chart's appVersion value will be used if not set)
  tag: "1.7.7"
  # image.pullPolicy -- image pull policy
  pullPolicy: IfNotPresent

## Optional array of imagePullSecrets containing private registry credentials
## Ref: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
imagePullSecrets:
  - name: private-registry

# nameOverride -- override name of the chart
nameOverride: ""
# fullnameOverride -- full name of the chart.
fullnameOverride: ""

serviceAccount:
  # serviceAccount.create -- specifies whether a service account should be created
  create: true
  # serviceAccount.annotations -- annotations to add to the service account
  annotations: {}
  # serviceAccount.name -- the name of the service account to use; if not set and create is true, a name is generated using the fullname template
  name: null

# podSecurityContext -- specifies security settings for a pod
podSecurityContext: {}
# fsGroup: 2000

## Changed from upstream to allow multiple ports
service:
  type: "ClusterIP"
  annotations: {}
  ports:
  - name: "cool-tcp"
    protocol: TCP
    containerPort: 8080
## end alteration

ingress:
  # ingress.enabled -- enables Ingress for envoy
  enabled: false
  # ingress.annotations -- ingress annotations
  annotations: {}
  # kubernetes.io/ingress.class: envoy
  # kubernetes.io/tls-acme: "true"
  # ingress.hosts -- ingress accepted hostnames
  hosts: []
  #  - host: chart-example.local
  #    paths: []
  # ingress.tls -- ingress TLS configuration
  tls: []
  #  - secretName: chart-example-tls
  #    hosts:
  #      - chart-example.local

# resources -- custom resource configuration
resources: {}
# limits:
#   cpu: 100m
#   memory: 128Mi
# requests:
#   cpu: 100m
#   memory: 128Mi

# nodeSelector -- node for scheduler pod assignment
nodeSelector: {}

# tolerations -- tolerations for scheduler pod assignment
tolerations: []

# affinity -- affinity for scheduler pod assignment
affinity: {}

# volumeMounts -- volume mounts
volumeMounts:
# Altered from upstream to demonstrate tls secrets
#  - name: certs
#    mountPath: /config/certs/
## end alteration

# volumes -- volumes
volumes:
## Altered from upstream to demonstrate tls secrets
#  - name: certs
#    secret:
#      secretName: wildcard-cert
## end alteration

# env -- environment variables for the deployment
env:
#  - name: NODE_LABEL_REGION
#    value: "failure-domain.beta.kubernetes.io/region"
#  - name: NODE_LABEL_INSTANCE_TYPE
#    value: "beta.kubernetes.io/instance-type"

# args -- extra args to pass to container
args: []
#  - --component-log-level
#  - config:debug,connection:debug,conn_handler:debug

serviceMonitor:
  # serviceMonitor.enabled -- ServiceMonitor CRD is created for a prometheus operator
  enabled: false
  # serviceMonitor.additionalLabels -- additional labels for service monitor
  additionalLabels: {}

livenessProbe:
  httpGet:
    # livenessProbe.httpGet.path -- path for liveness probe
    path: /ready
    # livenessProbe.httpGet.port -- port for liveness probe
    port: http-admin

readinessProbe:
  httpGet:
    # readinessProbe.httpGet.path -- path for readiness probe
    path: /ready
    # readinessProbe.httpGet.port -- port for readiness probe
    port: http-admin

## Added to the chart to support secret lookup for the certificate
lookUpCertificate:
  enabled: false
  namespace: istio-system
  secretName: wildcard-cert
## endaddition

# containerPort -- container port, should match static port_value from config.yaml
containerPort: 8080

# containerPort -- container port, should match admin port_value from config.yaml
containerAdminPort: 9901

# configYaml -- config yaml
configYaml: |-
  admin:
      access_log_path: /dev/stdout
      address:
        socket_address:
          address: 0.0.0.0
          port_value: 9901

  static_resources:
    listeners:
      - name: listener_0
        address:
          socket_address:
            address: 0.0.0.0
            port_value: 10000
        filter_chains:
          - filters:
              - name: envoy.http_connection_manager
                config:
                  access_log:
                    - name: envoy.file_access_log
                      config:
                        path: /dev/stdout
                  stat_prefix: ingress_http
                  route_config:
                    name: local_route
                    virtual_hosts:
                      - name: local_service
                        domains: ["*"]
                        routes:
                          - match:
                              prefix: "/"
                            route:
                              host_rewrite: www.google.com
                              cluster: service_google
                  http_filters:
                    - name: envoy.router

    clusters:
      - name: service_google
        connect_timeout: 0.25s
        type: LOGICAL_DNS
        dns_lookup_family: V4_ONLY
        lb_policy: ROUND_ROBIN
        hosts:
          - socket_address:
              address: google.com
              port_value: 443
        tls_context:
          sni: www.google.com
