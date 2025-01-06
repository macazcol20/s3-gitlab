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
    access_log_path: /tmp/admin_access.log
    address:
      socket_address:
        protocol: TCP
        address: 0.0.0.0
        port_value: 9901
  static_resources:
    listeners:
    - name: listener_0
      address:
        socket_address:
          address: 0.0.0.0
          port_value: 8080
      filter_chains:
        - filters:
            - name: envoy.http_connection_manager
              config:
                codec_type: auto
                stat_prefix: ingress_http
                route_config:
                  name: local_route
                  virtual_hosts:
                    - name: local_service
                      domains: ["*"]
                      routes:
                        - match: { prefix: "/" }
                          route:
                            cluster: reflect-project
                            max_grpc_timeout: 0s
                      cors:
                        allow_origin_string_match:
                        - safe_regex:
                            google_re2: {}
                            regex: \*
                        allow_methods: GET, PUT, DELETE, POST, OPTIONS
                        allow_headers: authorization,x-grpc-web,grpc-timeout,keep-alive,user-agent,cache-control,content-type,content-transfer-encoding,x-accept-content-transfer-encoding,x-accept-response-streaming,x-user-agent,x-reflect-appid
                        max_age: "1728000"
                        expose_headers: grpc-status,grpc-message
                http_filters:
                  - name: envoy.grpc_web
                  - name: envoy.cors
                  - name: envoy.router
  clusters:
    - name: reflect-project
      connect_timeout: 0.25s
      type: logical_dns  
      http2_protocol_options: {}
      lb_policy: round_robin
      # hosts: [{ socket_address: { address: $upstream_name, port_value: 10010 }}]  # collins commented this
      hosts: [{ socket_address: { address: argowf-argo-workflows-server.argo.svc.cluster.local, port_value: 2746 }}]  # collins updated address, using argowf as an example



# hostname: s3gis.be

# istio:
#   # Toggle istio interaction
#   enabled: true
#   envoy:
#     enabled: true
#     annotations: {}
#     labels: {}
#     gateways:
#       - istio-system/mimeo-gateway
#     hosts:
#       - host.{{ .Values.hostname }}
# ## End of addition 

# # replicaCount -- number of replicas for haproxy deployment.
# replicaCount: 1

# image:
#   # image.repository -- image repository
#   repository: registry1.dso.mil/ironbank/opensource/istio-1.7/proxyv2-1.7
#   # image.tag -- image tag (chart's appVersion value will be used if not set)
#   tag: "1.7.7"
#   # image.pullPolicy -- image pull policy
#   pullPolicy: IfNotPresent

# ## Optional array of imagePullSecrets containing private registry credentials
# ## Ref: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
# imagePullSecrets: []
#   # - name: private-registry

# # nameOverride -- override name of the chart
# nameOverride: ""
# # fullnameOverride -- full name of the chart.
# fullnameOverride: ""

# serviceAccount:
#   # serviceAccount.create -- specifies whether a service account should be created
#   create: true
#   # serviceAccount.annotations -- annotations to add to the service account
#   annotations: {}
#   # serviceAccount.name -- the name of the service account to use; if not set and create is true, a name is generated using the fullname template
#   name: null

# # podSecurityContext -- specifies security settings for a pod
# podSecurityContext: {}
# # fsGroup: 2000

# ## Changed from upstream to allow multiple ports
# service:
#   type: "ClusterIP"
#   annotations: {}
#   ports:
#   - name: "cool-tcp"
#     protocol: TCP
#     containerPort: 8080
# ## end alteration

# ingress:
#   # ingress.enabled -- enables Ingress for envoy
#   enabled: false
#   # ingress.annotations -- ingress annotations
#   annotations: {}
#   # kubernetes.io/ingress.class: envoy
#   # kubernetes.io/tls-acme: "true"
#   # ingress.hosts -- ingress accepted hostnames
#   hosts: []
#   #  - host: chart-example.local
#   #    paths: []
#   # ingress.tls -- ingress TLS configuration
#   tls: []
#   #  - secretName: chart-example-tls
#   #    hosts:
#   #      - chart-example.local

# # resources -- custom resource configuration
# resources: {}
# # limits:
# #   cpu: 100m
# #   memory: 128Mi
# # requests:
# #   cpu: 100m
# #   memory: 128Mi

# # nodeSelector -- node for scheduler pod assignment
# nodeSelector: {}

# # tolerations -- tolerations for scheduler pod assignment
# tolerations: []

# # affinity -- affinity for scheduler pod assignment
# affinity: {}

# # volumeMounts -- volume mounts
# volumeMounts:
# # Altered from upstream to demonstrate tls secrets
# #  - name: certs
# #    mountPath: /config/certs/
# ## end alteration

# # volumes -- volumes
# volumes:
# ## Altered from upstream to demonstrate tls secrets
# #  - name: certs
# #    secret:
# #      secretName: wildcard-cert
# ## end alteration

# # env -- environment variables for the deployment
# env:
# #  - name: NODE_LABEL_REGION
# #    value: "failure-domain.beta.kubernetes.io/region"
# #  - name: NODE_LABEL_INSTANCE_TYPE
# #    value: "beta.kubernetes.io/instance-type"

# # args -- extra args to pass to container
# args: []
# #  - --component-log-level
# #  - config:debug,connection:debug,conn_handler:debug

# serviceMonitor:
#   # serviceMonitor.enabled -- ServiceMonitor CRD is created for a prometheus operator
#   enabled: false
#   # serviceMonitor.additionalLabels -- additional labels for service monitor
#   additionalLabels: {}

# livenessProbe:
#   httpGet:
#     # livenessProbe.httpGet.path -- path for liveness probe
#     path: /ready
#     # livenessProbe.httpGet.port -- port for liveness probe
#     port: http-admin

# readinessProbe:
#   httpGet:
#     # readinessProbe.httpGet.path -- path for readiness probe
#     path: /ready
#     # readinessProbe.httpGet.port -- port for readiness probe
#     port: http-admin

# ## Added to the chart to support secret lookup for the certificate
# lookUpCertificate:
#   enabled: false
#   namespace: istio-system
#   secretName: wildcard-cert
# ## endaddition

# # containerPort -- container port, should match static port_value from config.yaml
# containerPort: 8080

# # containerPort -- container port, should match admin port_value from config.yaml
# containerAdminPort: 9901

# # configYaml -- config yaml
# configYaml: |-
#   admin:
#     access_log_path: /tmp/admin_access.log
#     address:
#       socket_address:
#         protocol: TCP
#         address: 0.0.0.0
#         port_value: 9901
#   static_resources:
#     listeners:
#     - name: listener_0
#       address:
#         socket_address:
#           address: 0.0.0.0
#           port_value: 8080
#       filter_chains:
#         - filters:
#             - name: envoy.http_connection_manager
#               config:
#                 codec_type: auto
#                 stat_prefix: ingress_http
#                 route_config:
#                   name: local_route
#                   virtual_hosts:
#                     - name: local_service
#                       domains: ["*"]
#                       routes:
#                         - match: { prefix: "/" }
#                           route:
#                             cluster: reflect-project
#                             max_grpc_timeout: 0s
#                       cors:
#                         allow_origin_string_match:
#                         - safe_regex:
#                             google_re2: {}
#                             regex: \*
#                         allow_methods: GET, PUT, DELETE, POST, OPTIONS
#                         allow_headers: authorization,x-grpc-web,grpc-timeout,keep-alive,user-agent,cache-control,content-type,content-transfer-encoding,x-accept-content-transfer-encoding,x-accept-response-streaming,x-user-agent,x-reflect-appid
#                         max_age: "1728000"
#                         expose_headers: grpc-status,grpc-message
#                 http_filters:
#                   - name: envoy.grpc_web
#                   - name: envoy.cors
#                   - name: envoy.router
#   clusters:
#     - name: reflect-project
#       connect_timeout: 0.25s
#       type: logical_dns
#       http2_protocol_options: {}
#       lb_policy: round_robin
#       # For local development on Windows, set `address` to `host.docker.internal` if the Project Server
#       # is not running inside Docker
#       #hosts: [{ socket_address: { address: host.docker.internal, port_value: 10010 }}]
#       hosts: [{ socket_address: { address: $upstream_name, port_value: 10010 }}] 