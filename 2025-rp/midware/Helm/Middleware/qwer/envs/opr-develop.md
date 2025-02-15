infra:
  postgresql: true
  keycloak: true
  rabbitmq: true
  project-grpc-nodeport: true
  postgres-integration-svc: true

rabbitmq:
  auth:
    username: admin
    password: rabbitmq-secret-key
    securePassword: false
  persistence:
    storageClass: longhorn

## The documenation for this chart can be found here: 
## https://github.com/codecentric/helm-charts/tree/master/charts/keycloak 
## This config assumes there is a secret named `realm-secret` that contains `realm.json`
## The config is mounted inside the container at `/opt/keycloak/data/import/realm.json`
keycloak:
  image:
    repository: registry1.dso.mil/ironbank/opensource/keycloak/keycloak
    tag: 21.1.2
  imagePullSecrets:
  - name: regcred-ironbank
  postgresql:
    enabled: false
  command:
    - "/opt/keycloak/bin/kc.sh"
  args:
    - "start-dev"
    - "--import-realm"
    - "--health-enabled=true"
  extraVolumes: |
    - name: realm-secret
      secret:
        secretName: realm-secret
  extraVolumeMounts: |
    - name: realm-secret
      mountPath: "/opt/keycloak/data/import/"
      readOnly: true
  extraEnv: |
    - name: KEYCLOAK_IMPORT
      value: /opt/keycloak/data/import/realm.json
    - name: KEYCLOAK_REFLECT_REALM_NAME
      value: "reflect"
    - name: KEYCLOAK_LOGLEVEL
      value: DEBUG
    - name: PROXY_ADDRESS_FORWARDING
      value: 'true'
    - name: KC_PROXY
      value: edge
    - name: KC_HOSTNAME_URL
      value: "https://keycloak.kapistiogroup.com"
  secrets:
    env:
      stringData:
        KEYCLOAK_ADMIN: "admin"
        KEYCLOAK_ADMIN_PASSWORD: "admin"
        KEYCLOAK_REFLECT_TEST_USERNAME: reflect-user
        KEYCLOAK_REFLECT_TEST_MANAGER_USERNAME: reflect-admin
        KEYCLOAK_REFLECT_TEST_ANONYMOUS_USERNAME: reflect-anonymous
  extraEnvFrom: |
    - secretRef:
        name: opr-keycloak-env
  livenessProbe: |
    httpGet:
      path: /health/live
      port: http
    initialDelaySeconds: 0
    timeoutSeconds: 5
  readinessProbe: |
    httpGet:
      path: /health/ready
      port: http
    initialDelaySeconds: 30
    timeoutSeconds: 1
  startupProbe: |
    httpGet:
      path: /health/started
      port: http
    initialDelaySeconds: 30
    timeoutSeconds: 1
    failureThreshold: 60
    periodSeconds: 5
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt
      nginx.ingress.kubernetes.io/cors-allow-origin: "https://dashboard.kapistiogroup.com"
      nginx.ingress.kubernetes.io/enable-cors: "true"
      nginx.ingress.kubernetes.io/cors-expose-headers: "*"
    rules:
      - 
        host: 'keycloak.kapistiogroup.com'
        paths: 
          - path: /
            pathType: Prefix
    tls:
      - secretName: keycloak-develop-tls
        hosts:
          - keycloak.kapistiogroup.com

## The documentation for this chart can be found here:
## https://github.com/bitnami/charts/tree/main/bitnami/postgresql
postgresql:
  global:
    imagePullSecrets:
      - regcred-ironbank
    auth:
      postgresPassword: "reflect"
  image:
    registry: registry1.dso.mil
    repository: ironbank/bitnami/postgres/postgresql11
    tag: 11.19.0
    pullSecrets:
    - name: regcred-ironbank
  auth:
    postgresPassword: "reflect"
  primary:
    persistence:
      storageClass: longhorn
      size: 5Gi
    extraEnvVars:
    - name: POSTGRES_USER
      value: "postgres"
    - name: PROJECT_SERVICE_DB_PASSWORD
      value: "reflect"
    - name: SYNC_SERVICE_DB_PASSWORD
      value: "reflect"
    - name: ANNOTATIONS_DB_PASSWORD
      value: "reflect"
    - name: MATCHMAKER_DB_PASSWORD
      value: "reflect"
    - name: MURMUR_DB_PASSWORD
      value: "reflect"
    initdb:
# This is a configmap that contains scripts and sql files that is mounted into the postgres container and executed on first boot
# UnComment if scripts have been added to a configmap. Will overwrite primary.initdb.scripts.*.  
      #scriptsConfigMap: "db-init"
# These are script used to intializse users in the postgres db. If using migrations to update/seed the database, uncomment the section below to initialize
# the user and databases for use in the migration scripts
      scripts:
        create_users.sql : | 
          CREATE USER project_service WITH ENCRYPTED PASSWORD 'reflect';
          CREATE DATABASE "ProjectService" WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.utf8' LC_CTYPE = 'en_US.utf8' OWNER project_service;
          CREATE USER sync_service WITH ENCRYPTED PASSWORD 'reflect';
          CREATE DATABASE "SyncService" WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.utf8' LC_CTYPE = 'en_US.utf8' OWNER sync_service;
          CREATE DATABASE "SyncService_Hangfire" WITH OWNER sync_service;
          CREATE USER annotations WITH ENCRYPTED PASSWORD 'reflect';
          CREATE DATABASE "Annotations" WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.utf8' LC_CTYPE = 'en_US.utf8' OWNER annotations;

## The project service chart depends on another chart `reflect-common-chart`
project:
  reflect-common-chart:
    imagePullSecrets:
      - name: regcred-gcp
    image:
      repository: us-east1-docker.pkg.dev/unity-solutions-tyndall-prd/docker/reflect-project
      tag: develop-latest
      pullPolicy: Always
    resources: {}
    serviceMonitor:
      enabled: false
    deployment:
      volumeMounts:
        - name: cert
          mountPath: /secrets/jwt
          readOnly: true
    volumes:
    - name: cert
      secret:
        secretName: project-cert
    ingress:
      project-grpc:
        annotations:
          nginx.ingress.kubernetes.io/cors-allow-origin: "https://dashboard.kapistiogroup.com"
          nginx.ingress.kubernetes.io/enable-cors: "true"
          nginx.ingress.kubernetes.io/cors-allow-headers: "x-user-agent,x-grpc-web,x-reflect-appid,x-reflect-clienttrace,authorization,content-type"
          nginx.ingress.kubernetes.io/cors-expose-headers: "*"
          cert-manager.io/cluster-issuer: letsencrypt
          nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
          nginx.ingress.kubernetes.io/proxy-body-size: 1024m
        ingressClassName: nginx
        hosts:
          - host: develop.opr.unity.com
            http:
              paths:
                - backend:
                    service:
                      name: project
                      port: 
                        name: grpc
                  path: /
                  pathType: ImplementationSpecific
          - host: web-develop.kapistiogroup.com
            http:
              paths:
                - backend:
                    service:
                      name: project
                      port: 
                        name: grpc-web
                  path: /
                  pathType: ImplementationSpecific
        tls:
          - secretName: develop-tls
            hosts:
              - develop.opr.unity.com
          - secretName: web-develop-tls
            hosts:
              - web-develop.kapistiogroup.com
      project-http:
        annotations:
          nginx.ingress.kubernetes.io/use-regex: "true"
          cert-manager.io/cluster-issuer: letsencrypt
        ingressClassName: nginx
        hosts:
          - host: develop.opr.unity.com
            http:
              paths:
                - backend:
                    service:
                      name: project
                      port:
                        name: http
                  path: /(api|swagger|v1)
                  pathType: Prefix
        tls:
          - secretName: develop-tls
            hosts:
              - develop.opr.unity.com

    workloadIdentity:
      enabled: false
    cloudSqlSidecar:
      enabled: false
    autoscaling:
      enabled: false
#    volumes:
#      - name: jwt
#        secret:
#          defaultMode: 420
#          secretName: jwt
    serviceAccount:
      create: true
      name: reflect-project-sa
    deployment:
      envFrom:
      - secretRef:
          name: project-external-secrets
      - configMapRef:
          name: project-config
      env:   # collins
        - name: ASPNETCORE_URLS 
          value: http://+:8090 
    configMaps:
      project-config:
        data:
          REFLECT_ENVIRONMENT: "Production"
          ASPNETCORE_URLS: http://+:8090 # collins
          URLS: http://+:8090   # collins
          REFLECTPROJECT_ServerEndpoint__Host: 0.0.0.0
          REFLECT_CLOUD: "OnPrem"
          REFLECT_DOMAIN: "BAH OPR"
          REFLECTPROJECT_LinkSharing__Domain: "https://links.kapistiogroup.com"
          REFLECTPROJECT_LinkSharing__Path: "p/"
          REFLECTPROJECT_Security__OnPrem__OrganizationName: "Tyndall Air Force Base"
          REFLECTPROJECT_Security__OnPrem__ClientId: "reflect"
          REFLECTPROJECT_Security__OnPrem__ValidIssuer: "https://keycloak.kapistiogroup.com/realms/reflect"
          REFLECTPROJECT_Security__OnPrem__Domain: "BAH OPR"
          REFLECTPROJECT_Security__OnPrem__Scope: "openid"
          REFLECTPROJECT_Security__OnPrem__ViewerProtocol: "reflect"
          REFLECTPROJECT_Security__OnPrem__ClientIdClaim: "azp"
          REFLECTPROJECT_Security__OnPrem__NameClaim: "preferred_username"
          REFLECTPROJECT_Security__OnPrem__RealmAccessRoleListOwnerOrManagerRole: "ReflectOwnerManagerRole"
          REFLECTPROJECT_Security__OnPrem__RealmAccessRoleListUserRole: "ReflectUserRole"
          REFLECTPROJECT_Security__OnPrem__AuthorizeEndpoint: "https://keycloak.kapistiogroup.com/realms/reflect/protocol/openid-connect/auth"
          REFLECTPROJECT_Security__OnPrem__RevokeEndpoint: "https://keycloak.kapistiogroup.com/realms/reflect/protocol/openid-connect/revoke"
          REFLECTPROJECT_Security__OnPrem__TokenEndpoint: "https://keycloak.kapistiogroup.com/realms/reflect/protocol/openid-connect/token"
          REFLECTPROJECT_Security__OnPrem__RefreshEndpoint: "https://keycloak.kapistiogroup.com/realms/reflect/protocol/openid-connect/token"
          REFLECTPROJECT_Security__OnPrem__OAuthJwkUrl: "https://keycloak.kapistiogroup.com/realms/reflect/protocol/openid-connect/certs"
          REFLECTPROJECT_Security__OnPrem__UserInfoEndpoint: "https://keycloak.kapistiogroup.com/realms/reflect/protocol/openid-connect/userinfo"
          REFLECTPROJECT_SyncServer__Cloud__Address: "https://sync-develop.kapistiogroup.com"
          REFLECTPROJECT_ServiceEndpoints__Annotations__HttpAddress: "https://annotations.kapistiogroup.com"
          REFLECTPROJECT_ServiceEndpoints__MatchMaker__HttpAddress: "https://matchmaker.kapistiogroup.com"
          REFLECTPROJECT_ServiceEndpoints__MatchMaker__GrpcAddress: "https://matchmaker.kapistiogroup.com"
          REFLECTPROJECT_ServiceEndpoints__ProjectServer__HttpAddress: "https://develop.kapistiogroup.com"
          REFLECTPROJECT_ServiceEndpoints__ProjectServer__GrpcAddress: "https://develop.kapistiogroup.com"
          REFLECTPROJECT_ServiceEndpoints__ProjectServer__GrpcWebAddress: "https://web-develop.kapistiogroup.com"
          REFLECTPROJECT_ServiceEndpoints__VoipServer__OtherServerAddress: "mumble://voip-develop.opr.unity.com:30000"
          OTEL_EXPORTER_OTLP_ENDPOINT: "http://apm-server-apm-http:8200"
          OTEL_EXPORTER_OTLP_HEADERS: "Authorization=Bearer 4113wNO7AFYO336Yn3vj2yvP"
          OTEL_RESOURCE_ATTRIBUTES: "deployment.environment=production"
          OTEL_SERVICE_NAME: "project"
    # disables external secrets and use standard k8s secrets
    externalSecrets:
      enabled: false
    # Secrets for reflect-project container
    secrets:
      project-external-secrets:
        type: Opaque
        data:
          REFLECTPROJECT_ConnectionStrings__ProjectServiceDatabase: "Host=opr-postgresql;Database=ProjectService;Username=project_service;Password=reflect"
          REFLECTPROJECT_SyncServer__Cloud__ClientId: "syncid"
          REFLECTPROJECT_SyncServer__Cloud__ClientSecret: "syncsecret"
    # Envoy required to upgrade grpc connections
    sidecarContainers:
      enabled: true
      containers:
        - image: us-east1-docker.pkg.dev/unity-solutions-tyndall-prd/docker/reflect-envoy-k8s:develop-latest
          imagePullPolicy: Always
          securityContext:
            runAsUser: 2
            allowPrivilegeEscalation: false
          name: envoy
          resources: {}

sync:
  api:
    reflect-common-chart:
      image:
        repository: us-east1-docker.pkg.dev/unity-solutions-tyndall-prd/docker/reflect-sync
        tag: develop-latest
        pullPolicy: Always
      imagePullSecrets:
        - name: regcred-gcp
      serviceMonitor:
        enabled: false
      cloudSqlSidecar:
        enabled: false
      autoscaling:
        enabled: false
      podMonitor:
        enabled: false
      configMaps:
        sync-api-config:
          data:
            REFLECT_ENVIRONMENT: "Production"
            REFLECTSYNC_HttpServer__ExceptionContextResponseEnabled: "true"
            REFLECTSYNC_Storage__Backend: Bucket
            REFLECTSYNC_Storage__Bucket__BucketName__Default: sync-service-dev
            REFLECTSYNC_Storage__Bucket__ProviderName: AWS
            REFLECTSYNC_Storage__Bucket__ProviderUrl: https://minio-instance.kapistiogroup.com
            REFLECTSYNC_Swagger__Enabled: "false"
            REFLECTSYNC_MessageBroker__Backend: MassTransit
            REFLECTSYNC_MessageBroker__MassTransit__Transport: RabbitMQ
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__SyncSessionTopicId: sync-sessions
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__HostName: opr-rabbitmq
            # REFLECTSYNC_PixyzOptimizeSdk__Enabled: "false"
            REFLECTSYNC_Kestrel__EndpointDefaults__Protocols: Http1AndHttp2
            REFLECTSYNC_Storage__Bucket__RetryPolicy__InitialDelay: "00:00:01"
            REFLECTSYNC_Storage__Bucket__RetryPolicy__MaxRetries: "10"
            REFLECTSYNC_ProjectMetadata__Backend: "Database"
            REFLECTSYNC_ProjectServer__Address: "https://web-develop.kapistiogroup.com"
            REFLECTSYNC_ProjectServer__HttpAddress: "https://develop.kapistiogroup.com"
            REFLECTSYNC_Logging__LogLevel__Default: "Debug"
            OTEL_EXPORTER_OTLP_ENDPOINT: "http://apm-server-apm-http:8200"
            OTEL_EXPORTER_OTLP_HEADERS: "Authorization=Bearer 4113wNO7AFYO336Yn3vj2yvP"
            OTEL_RESOURCE_ATTRIBUTES: "deployment.environment=production"
      secrets:
        sync-api-secrets:
          type: Opaque
          data:
            REFLECTSYNC_ConnectionStrings__SyncServiceDatabase: "Host=opr-postgresql;Database=SyncService;Username=sync_service;Password=reflect"
            REFLECTSYNC_ProjectServer__ClientId: "syncid"
            REFLECTSYNC_ProjectServer__ClientSecret: "syncsecret"
            REFLECTSYNC_Storage__Bucket__AccessKeyId: minio
            REFLECTSYNC_Storage__Bucket__SecretAccessKey: minio123
            REFLECTSYNC_MessageBroker__MassTransit__HangfireConnectionString: "Host=opr-postgresql;Database=SyncService_Hangfire;Username=sync_service;Password=reflect"
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__Username: admin
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__Password: rabbitmq-secret-key
      ingress:
        sync-api-grpc:
          ingressClassName: nginx
          hosts:
            - host: sync-develop.kapistiogroup.com
              http:
                paths:
                  - backend:
                      service:
                        name: sync-api
                        port:
                          name: grpc
                    path: /
                    pathType: ImplementationSpecific
          tls:
            - secretName: sync-develop-tls
              hosts:
                - sync-develop.kapistiogroup.com
        sync-api-http:
          ingressClassName: nginx
          hosts:
            - host: sync-develop.kapistiogroup.com
              http:
                paths:
                  - backend:
                      service:
                        name: sync-api
                        port:
                          name: http
                    path: /api
                    pathType: ImplementationSpecific
          tls:
            - secretName: sync-develop-tls
              hosts:
                - sync-develop.kapistiogroup.com
  
  decimator:
    reflect-common-chart:
      image:
        repository: us-east1-docker.pkg.dev/unity-solutions-tyndall-prd/docker/reflect-sync
        tag: develop-latest
        pullPolicy: Always
      imagePullSecrets:
        - name: regcred-gcp
      serviceMonitor:
        enabled: false
      cloudSqlSidecar:
        enabled: false
      autoscaling:
        enabled: false
      configMaps:
        sync-decimator-config:
          data:
            REFLECT_ENVIRONMENT: "Production"
            REFLECTSYNC_HttpServer__ExceptionContextResponseEnabled: "true"
            REFLECTSYNC_Storage__Backend: Bucket
            REFLECTSYNC_Storage__Bucket__BucketName__Default: sync-service-dev
            REFLECTSYNC_Storage__Bucket__ProviderName: AWS
            REFLECTSYNC_Storage__Bucket__ProviderUrl: https://minio-instance.kapistiogroup.com
            REFLECTSYNC_Swagger__Enabled: "false"
            REFLECTSYNC_MessageBroker__Backend: MassTransit
            REFLECTSYNC_MessageBroker__MassTransit__Transport: RabbitMQ
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__HostName: opr-rabbitmq
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__SyncSessionTopicId: sync-sessions
            # REFLECTSYNC_PixyzOptimizeSdk__Enabled: "false"
            # REFLECTSYNC_PixyzOptimizeSdk__LicenseFilePath: "/app/licenses/license"
            # REFLECTSYNC_PixyzOptimizeSdk__LogFileBasePath: "/app/log/pixyz"
            REFLECTSYNC_Kestrel__EndpointDefaults__Protocols: Http1AndHttp2
            REFLECTSYNC_Storage__Bucket__RetryPolicy__InitialDelay: "00:00:01"
            REFLECTSYNC_Storage__Bucket__RetryPolicy__MaxRetries: "10"
            REFLECTSYNC_ProjectMetadata__Backend: "Database"
            REFLECTSYNC_ProjectServer__Address: "https://web-develop.kapistiogroup.com"
            REFLECTSYNC_ProjectServer__HttpAddress: "https://develop.kapistiogroup.com"
            OTEL_EXPORTER_OTLP_ENDPOINT: "http://apm-server-apm-http:8200"
            OTEL_EXPORTER_OTLP_HEADERS: "Authorization=Bearer 4113wNO7AFYO336Yn3vj2yvP"
            OTEL_RESOURCE_ATTRIBUTES: "deployment.environment=production"
      secrets:
        sync-decimator-secrets:
          type: Opaque
          data:
            REFLECTSYNC_ConnectionStrings__SyncServiceDatabase: "Host=opr-postgresql;Database=SyncService;Username=sync_service;Password=reflect"
            REFLECTSYNC_ProjectServer__ClientId: "syncid"
            REFLECTSYNC_ProjectServer__ClientSecret: "syncsecret"
            REFLECTSYNC_Storage__Bucket__AccessKeyId: minio
            REFLECTSYNC_Storage__Bucket__SecretAccessKey: minio123
            REFLECTSYNC_MessageBroker__MassTransit__HangfireConnectionString: "Host=opr-postgresql;Database=SyncService_Hangfire;Username=sync_service;Password=reflect"
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__Username: admin
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__Password: rabbitmq-secret-key

      volumes:
        # - name: pixyz-license
        #   secret:
        #     secretName: pixyz-license
        #     items:
        #     - key: license-file
        #       path: license
        - name: scratch-volume
          emptyDir:
            medium: Memory
      deployment:
        # env:
        # - name: REFLECTSYNC_PixyzOptimizeSdk__ValidationKey
        #   valueFrom:
        #     secretKeyRef: 
        #       name: pixyz-license
        #       key: validation-key
        volumeMounts:
          # - name: pixyz-license
          #   mountPath: /app/licenses/
          #   readOnly: true
          - mountPath: /storage
            name: scratch-volume

  hlodbuilder:
    reflect-common-chart:
      image:
        repository: us-east1-docker.pkg.dev/unity-solutions-tyndall-prd/docker/reflect-sync
        tag: develop-latest
        pullPolicy: Always
      imagePullSecrets:
        - name: regcred-gcp
      serviceMonitor:
        enabled: false
      cloudSqlSidecar:
        enabled: false
      autoscaling:
        enabled: false
      overprovisioning:
        enabled: false
      configMaps:
        sync-hlodbuilder-config:
          data:
            REFLECT_ENVIRONMENT: "Production"
            REFLECTSYNC_HttpServer__ExceptionContextResponseEnabled: "true"
            REFLECTSYNC_Storage__Backend: Bucket
            REFLECTSYNC_Storage__Bucket__BucketName__Default: sync-service-dev
            REFLECTSYNC_Storage__Bucket__ProviderName: AWS
            REFLECTSYNC_Storage__Bucket__ProviderUrl: https://minio-instance.kapistiogroup.com
            REFLECTSYNC_Swagger__Enabled: "false"
            REFLECTSYNC_MessageBroker__Backend: MassTransit
            REFLECTSYNC_MessageBroker__MassTransit__Transport: RabbitMQ
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__SyncSessionTopicId: sync-sessions
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__HostName: opr-rabbitmq
            # REFLECTSYNC_PixyzOptimizeSdk__Enabled: "false"
            # REFLECTSYNC_PixyzOptimizeSdk__LicenseFilePath: "/app/licenses/license"
            # REFLECTSYNC_PixyzOptimizeSdk__LogFileBasePath: "/app/pixyzlog/pixyz"
            REFLECTSYNC_Kestrel__EndpointDefaults__Protocols: Http1AndHttp2
            REFLECTSYNC_Storage__Bucket__RetryPolicy__InitialDelay: "00:00:01"
            REFLECTSYNC_Storage__Bucket__RetryPolicy__MaxRetries: "10"
            REFLECTSYNC_ProjectMetadata__Backend: "Database"
            REFLECTSYNC_ProjectServer__Address: "https://web-develop.kapistiogroup.com"
            REFLECTSYNC_ProjectServer__HttpAddress: "https://develop.kapistiogroup.com"
            OTEL_EXPORTER_OTLP_ENDPOINT: "http://apm-server-apm-http:8200"
            OTEL_EXPORTER_OTLP_HEADERS: "Authorization=Bearer 4113wNO7AFYO336Yn3vj2yvP"
            OTEL_RESOURCE_ATTRIBUTES: "deployment.environment=production"
      secrets:
        sync-hlodbuilder-secrets:
          type: Opaque
          data:
            REFLECTSYNC_ConnectionStrings__SyncServiceDatabase: "Host=opr-postgresql;Database=SyncService;Username=sync_service;Password=reflect"
            REFLECTSYNC_ProjectServer__ClientId: "syncid"
            REFLECTSYNC_ProjectServer__ClientSecret: "syncsecret"
            REFLECTSYNC_Storage__Bucket__AccessKeyId: minio
            REFLECTSYNC_Storage__Bucket__SecretAccessKey: minio123
            REFLECTSYNC_MessageBroker__MassTransit__HangfireConnectionString: "Host=opr-postgresql;Database=SyncService_Hangfire;Username=sync_service;Password=reflect"
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__Username: admin
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__Password: rabbitmq-secret-key
      volumes:
        # - name: pixyz-license
        #   secret:
        #     secretName: pixyz-license
        #     items:
        #     - key: license-file
        #       path: license
        - name: scratch-volume
          emptyDir:
            medium: Memory
      deployment:
        # env:
        # - name: REFLECTSYNC_PixyzOptimizeSdk__ValidationKey
        #   valueFrom:
        #     secretKeyRef: 
        #       name: pixyz-license
        #       key: validation-key
        volumeMounts:
          # - name: pixyz-license
          #   mountPath: /app/licenses/
          #   readOnly: true
          - mountPath: /storage
            name: scratch-volume

  worker:
    reflect-common-chart:
      image:
        repository: us-east1-docker.pkg.dev/unity-solutions-tyndall-prd/docker/reflect-sync
        tag: develop-latest
        pullPolicy: Always
      imagePullSecrets:
        - name: regcred-gcp
      serviceMonitor:
        enabled: false
      cloudSqlSidecar:
        enabled: false
      autoscaling:
        enabled: false
      podMonitor:
        enabled: false
      configMaps:
        sync-worker-config:
          data:
            REFLECT_ENVIRONMENT: "Production"
            REFLECTSYNC_HttpServer__ExceptionContextResponseEnabled: "true"
            REFLECTSYNC_Storage__Backend: Bucket
            REFLECTSYNC_Storage__Bucket__BucketName__Default: sync-service-dev
            REFLECTSYNC_Storage__Bucket__ProviderName: AWS
            REFLECTSYNC_Storage__Bucket__ProviderUrl: https://minio-instance.kapistiogroup.com
            REFLECTSYNC_Swagger__Enabled: "false"
            REFLECTSYNC_MessageBroker__Backend: MassTransit
            REFLECTSYNC_MessageBroker__MassTransit__Transport: RabbitMQ
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__SyncSessionTopicId: sync-sessions
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__HostName: opr-rabbitmq
            # REFLECTSYNC_PixyzOptimizeSdk__Enabled: "false"
            REFLECTSYNC_Kestrel__EndpointDefaults__Protocols: Http1AndHttp2
            REFLECTSYNC_Storage__Bucket__RetryPolicy__InitialDelay: "00:00:01"
            REFLECTSYNC_Storage__Bucket__RetryPolicy__MaxRetries: "10"
            REFLECTSYNC_ProjectMetadata__Backend: "Database"
            REFLECTSYNC_ProjectServer__Address: "https://web-develop.kapistiogroup.com"
            REFLECTSYNC_ProjectServer__HttpAddress: "https://develop.kapistiogroup.com"
            OTEL_EXPORTER_OTLP_ENDPOINT: "http://apm-server-apm-http:8200"
            OTEL_EXPORTER_OTLP_HEADERS: "Authorization=Bearer 4113wNO7AFYO336Yn3vj2yvP"
            OTEL_RESOURCE_ATTRIBUTES: "deployment.environment=production"
      secrets:
        sync-worker-secrets:
          type: Opaque
          data:
            REFLECTSYNC_ConnectionStrings__SyncServiceDatabase: "Host=opr-postgresql;Database=SyncService;Username=sync_service;Password=reflect"
            REFLECTSYNC_ProjectServer__ClientId: "syncid"
            REFLECTSYNC_ProjectServer__ClientSecret: "syncsecret"
            REFLECTSYNC_Storage__Bucket__AccessKeyId: minio
            REFLECTSYNC_Storage__Bucket__SecretAccessKey: minio123
            REFLECTSYNC_MessageBroker__MassTransit__HangfireConnectionString: "Host=opr-postgresql;Database=SyncService_Hangfire;Username=sync_service;Password=reflect"
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__Username: admin
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__Password: rabbitmq-secret-key
  
  modelprocessor:
    reflect-common-chart:
      image:
        repository: us-east1-docker.pkg.dev/unity-solutions-tyndall-prd/docker/reflect-sync
        tag: develop-latest
        pullPolicy: Always
      imagePullSecrets:
        - name: regcred-gcp
      serviceMonitor:
        enabled: false
      cloudSqlSidecar:
        enabled: false
      autoscaling:
        enabled: false
      configMaps:
        sync-modelprocessor-config:
          data:
            REFLECT_ENVIRONMENT: "Production"
            REFLECTSYNC_HttpServer__ExceptionContextResponseEnabled: "true"
            REFLECTSYNC_Storage__Backend: Bucket
            REFLECTSYNC_Storage__Bucket__BucketName__Default: sync-service-dev
            REFLECTSYNC_Storage__Bucket__ProviderName: AWS
            REFLECTSYNC_Storage__Bucket__ProviderUrl: https://minio-instance.kapistiogroup.com
            REFLECTSYNC_Swagger__Enabled: "false"
            REFLECTSYNC_MessageBroker__Backend: MassTransit
            REFLECTSYNC_MessageBroker__MassTransit__Transport: RabbitMQ
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__SyncSessionTopicId: sync-sessions
            # REFLECTSYNC_PixyzOptimizeSdk__Enabled: "false"
            REFLECTSYNC_Kestrel__EndpointDefaults__Protocols: Http1AndHttp2
            REFLECTSYNC_Storage__Bucket__RetryPolicy__InitialDelay: "00:00:01"
            REFLECTSYNC_Storage__Bucket__RetryPolicy__MaxRetries: "10"
            REFLECTSYNC_ProjectMetadata__Backend: "Database"
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__HostName: opr-rabbitmq
            REFLECTSYNC_ProjectServer__Address: "https://web-develop.kapistiogroup.com"
            REFLECTSYNC_ProjectServer__HttpAddress: "https://develop.kapistiogroup.com"
            OTEL_EXPORTER_OTLP_ENDPOINT: "http://apm-server-apm-http:8200"
            OTEL_EXPORTER_OTLP_HEADERS: "Authorization=Bearer 4113wNO7AFYO336Yn3vj2yvP" #TODO: use secretKeyRef to get the `secret-token` from apm-server-apm-token 
            OTEL_RESOURCE_ATTRIBUTES: "deployment.environment=production"
      secrets:
        sync-modelprocessor-secrets:
          type: Opaque
          data:
            REFLECTSYNC_ConnectionStrings__SyncServiceDatabase: "Host=opr-postgresql;Database=SyncService;Username=sync_service;Password=reflect"
            REFLECTSYNC_ProjectServer__ClientId: "syncid"
            REFLECTSYNC_ProjectServer__ClientSecret: "syncsecret"
            REFLECTSYNC_Storage__Bucket__AccessKeyId: minio
            REFLECTSYNC_Storage__Bucket__SecretAccessKey: minio123
            REFLECTSYNC_MessageBroker__MassTransit__HangfireConnectionString: "Host=opr-postgresql;Database=SyncService_Hangfire;Username=sync_service;Password=reflect"
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__Username: admin
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__Password: rabbitmq-secret-key
  
  
  modelprocessor-safemode:
    reflect-common-chart:
      image:
        repository: us-east1-docker.pkg.dev/unity-solutions-tyndall-prd/docker/reflect-sync
        tag: develop-latest
        pullPolicy: Always
      imagePullSecrets:
        - name: regcred-gcp
      serviceMonitor:
        enabled: false
      cloudSqlSidecar:
        enabled: false
      autoscaling:
        enabled: false
      configMaps:
        sync-modelprocessor-safemode-config:
          data:
            REFLECT_ENVIRONMENT: "Production"
            REFLECTSYNC_HttpServer__ExceptionContextResponseEnabled: "true"
            REFLECTSYNC_Storage__Backend: Bucket
            REFLECTSYNC_Storage__Bucket__BucketName__Default: sync-service-dev
            REFLECTSYNC_Storage__Bucket__ProviderName: AWS
            REFLECTSYNC_Storage__Bucket__ProviderUrl: https://minio-instance.kapistiogroup.com
            REFLECTSYNC_Swagger__Enabled: "false"
            REFLECTSYNC_MessageBroker__Backend: MassTransit
            REFLECTSYNC_MessageBroker__MassTransit__Transport: RabbitMQ
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__SyncSessionTopicId: sync-sessions
            # REFLECTSYNC_PixyzOptimizeSdk__Enabled: "false"
            # REFLECTSYNC_PixyzOptimizeSdk__LicenseFilePath: "/app/licenses/license"
            # REFLECTSYNC_PixyzOptimizeSdk__LogFileBasePath: "/app/pixyzlog/pixyz"
            REFLECTSYNC_Kestrel__EndpointDefaults__Protocols: Http1AndHttp2
            REFLECTSYNC_Storage__Bucket__RetryPolicy__InitialDelay: "00:00:01"
            REFLECTSYNC_Storage__Bucket__RetryPolicy__MaxRetries: "10"
            REFLECTSYNC_ProjectMetadata__Backend: "Database"
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__HostName: opr-rabbitmq
            REFLECTSYNC_ProjectServer__Address: "https://web-develop.kapistiogroup.com"
            REFLECTSYNC_ProjectServer__HttpAddress: "https://develop.kapistiogroup.com"
            OTEL_EXPORTER_OTLP_ENDPOINT: "http://apm-server-apm-http:8200"
            OTEL_EXPORTER_OTLP_HEADERS: "Authorization=Bearer 4113wNO7AFYO336Yn3vj2yvP"
            OTEL_RESOURCE_ATTRIBUTES: "deployment.environment=production"
      secrets:
        sync-modelprocessor-safemode-secrets:
          type: Opaque
          data:
            REFLECTSYNC_ConnectionStrings__SyncServiceDatabase: "Host=opr-postgresql;Database=SyncService;Username=sync_service;Password=reflect"
            REFLECTSYNC_ProjectServer__ClientId: "syncid"
            REFLECTSYNC_ProjectServer__ClientSecret: "syncsecret"
            REFLECTSYNC_Storage__Bucket__AccessKeyId: minio
            REFLECTSYNC_Storage__Bucket__SecretAccessKey: minio123
            REFLECTSYNC_MessageBroker__MassTransit__HangfireConnectionString: "Host=opr-postgresql;Database=SyncService_Hangfire;Username=sync_service;Password=reflect"
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__Username: admin
            REFLECTSYNC_MessageBroker__MassTransit__RabbitMq__Password: rabbitmq-secret-key
      volumes:
        # - name: pixyz-license
        #   secret:
        #     secretName: pixyz-license
        #     items:
        #     - key: license-file
        #       path: license
        - name: scratch-volume
          emptyDir:
            medium: Memory
      deployment:
        # env:
        # - name: REFLECTSYNC_PixyzOptimizeSdk__ValidationKey
        #   valueFrom:
        #     secretKeyRef: 
        #       name: pixyz-license
        #       key: validation-key
        volumeMounts:
          # - name: pixyz-license
          #   mountPath: /app/licenses/
          #   readOnly: true
          - mountPath: /storage
            name: scratch-volume

annotations:
  reflect-common-chart:
    image:
      repository: us-east1-docker.pkg.dev/unity-solutions-tyndall-prd/docker/reflect-annotations
      tag: develop-latest
      pullPolicy: Always
    imagePullSecrets:
      - name: regcred-gcp
    ingress:
      annotations:
        annotations:
          cert-manager.io/cluster-issuer: letsencrypt
        ingressClassName: nginx
        hosts:
          - host: annotations.kapistiogroup.com
            http:
              paths:
                - backend:
                    service:
                      name: annotations
                      port: 
                        name: http
                  path: /
                  pathType: ImplementationSpecific
        tls:
          - secretName: annotations-develop-tls
            hosts:
              - annotations.kapistiogroup.com
    cloudSqlSidecar:
      enabled: false
    serviceMonitor:
      enabled: false
    autoscaling:
      enabled: false
    configMaps:
      annotations-config:
        data:
          REFLECT_ENVIRONMENT: "Production"
          ASPNETCORE_URLS: http://+:8090  # collins
          URLS: http://+:8090   # collins
          REFLECTANNOTATIONS_ProjectServer__Address: "https://web-develop.kapistiogroup.com"
          REFLECTANNOTATIONS_ProjectServer__HttpAddress: "https://develop.kapistiogroup.com"
          REFLECTANNOTATIONS_Multiplayer__Address: "https://multiplayer-develop.opr.unity.com" # TODO: Double check value once OPRTDL-549 has been worked on.
          REFLECTANNOTATIONS_Swagger__Enabled: "false"
          OTEL_EXPORTER_OTLP_ENDPOINT: "http://apm-server-apm-http:8200"
          OTEL_EXPORTER_OTLP_HEADERS: "Authorization=Bearer 4113wNO7AFYO336Yn3vj2yvP"
          OTEL_RESOURCE_ATTRIBUTES: "deployment.environment=production"
          OTEL_SERVICE_NAME: "annotations"
    secrets:
      annotations-secret:
        type: Opaque
        data:
          REFLECTANNOTATIONS_ConnectionStrings__AnnotationsDatabase: "Host=opr-postgresql;Database=Annotations;Username=annotations;Password=reflect"
#          REFLECTANNOTATIONS_Sentry__Dsn: gcp:secretmanager:projects/unity-vert-reflect-prd/secrets/env_REFLECTANNOTATIONS_Sentry__Dsn
    nodeSelector: 

links:
  reflect-common-chart:
    image:
      repository: us-east1-docker.pkg.dev/unity-solutions-tyndall-prd/docker/reflect-links
      tag: develop-latest
      pullPolicy: Always
    imagePullSecrets:
      - name: regcred-gcp
    ingress:
      links-http:
        annotations:
          cert-manager.io/cluster-issuer: letsencrypt
        ingressClassName: nginx
        hosts:
          - host: links.kapistiogroup.com
            http:
              paths:
                - backend:
                    service:
                      name: links
                      port:
                        name: http
                  path: /
                  pathType: ImplementationSpecific
        tls:
          - secretName: links-develop-tls
            hosts:
              - links.kapistiogroup.com
    cloudSqlSidecar:
      enabled: false
    serviceMonitor:
      enabled: false
    autoscaling:
      enabled: false
    configMaps:
      links-config:
        data:
          REFLECT_ENVIRONMENT: "Production"
          ASPNETCORE_URLS: http://+:8090  # collins
          URLS: http://+:8090   # collins
          REFLECTLINKS_LinkSharing__Domain: "links.kapistiogroup.com"
          OTEL_EXPORTER_OTLP_ENDPOINT: "http://apm-server-apm-http:8200"
          OTEL_EXPORTER_OTLP_HEADERS: "Authorization=Bearer 4113wNO7AFYO336Yn3vj2yvP"
          OTEL_RESOURCE_ATTRIBUTES: "deployment.environment=production"
          OTEL_SERVICE_NAME: "links"

multiplayer:
  netcode:
    reflect-common-chart:
      clusterRoleBinding:
        create: true
        name: netcode-rb
        subjects:
          - kind: ServiceAccount
            name: netcode-sa
            namespace: opr-develop
        roleRef:
          kind: ClusterRole
          name: netcode-clusterrole
          apiGroup: rbac.authorization.k8s.io
  matchmaker:
    reflect-common-chart:
      image:
        repository: us-east1-docker.pkg.dev/unity-solutions-tyndall-prd/docker/reflect-matchmaker
        tag: develop-latest
        pullPolicy: Always
      imagePullSecrets:
        - name: regcred-gcp
      ingress:
        matchmaker-grpc:
          annotations:
            cert-manager.io/cluster-issuer: letsencrypt
          ingressClassName: nginx
          hosts:
            - host: matchmaker.kapistiogroup.com
              http:
                paths:
                  - backend:
                      service:
                        name: matchmaker
                        port:
                          name: grpc
                    path: /
                    pathType: ImplementationSpecific
          tls:
            - secretName: matchmaker-reflect-tls
              hosts:
                - matchmaker.kapistiogroup.com
        matchmaker-http:
          annotations:
            cert-manager.io/cluster-issuer: letsencrypt
          ingressClassName: nginx
          hosts:
            - host: matchmaker.kapistiogroup.com
              http:
                paths:
                  - backend:
                      service:
                        name: matchmaker
                        port:
                          name: http
                    path: /api
                    pathType: ImplementationSpecific
          tls:
            - secretName: matchmaker-reflect-tls
              hosts:
                - matchmaker.kapistiogroup.com
      clusterRoleBinding:
        create: true
        name: matchmaker-rb
        subjects:
          - kind: ServiceAccount
            name: matchmaker-sa
            namespace:
              opr-develop
      cloudSqlSidecar:
        enabled: false
      autoscaling:
        enabled: false
      serviceMonitor:
        enabled: false
  #    I don't think we need this for OPR
  #    nodeSelector:
  #      'cloud.google.com/gke-nodepool': reflect-matchmaker
      configMaps:
        matchmaker-config:
          data:
            REFLECT_ENVIRONMENT: "Production"
            ASPNETCORE_URLS: http://+:8090  # collins
            URLS: http://+:8090   # collins
            REFLECT_COMPONENT: matchmaker
            REFLECTMULTIPLAYER_ClusterController__KubeApi__Images__Init: "us-east1-docker.pkg.dev/unity-solutions-tyndall-prd/docker/reflect-netcode-init:develop-latest"
            REFLECTMULTIPLAYER_ClusterController__KubeApi__Images__Netcode: "us-east1-docker.pkg.dev/unity-solutions-tyndall-prd/docker/reflect-netcode:develop-latest"
            REFLECTMULTIPLAYER_ClusterController__KubeApi__NetcodeServerAddress: "develop.opr.unity.com"
            REFLECTMULTIPLAYER_ClusterController__KubeApi__CertsSecretName: "matchmaker-reflect-tls"
            REFLECTMULTIPLAYER_ClusterController__KubeApi__KubeNamespace: "opr-develop"
            REFLECTMULTIPLAYER_ClusterController__KubeApi__KubeNodepool: "kubernetes.io/os : linux"
            REFLECTMULTIPLAYER_ClusterController__AllocationPool__PoolSize: "0"
            REFLECTMULTIPLAYER_ProjectServer__HttpAddress: "https://develop.kapistiogroup.com"
            REFLECTMULTIPLAYER_Mumble__RestApiUrl: "http://mumble-rest.opr-develop.svc.cluster.local:8082"
            OTEL_EXPORTER_OTLP_ENDPOINT: "http://apm-server-apm-http:8200"
            OTEL_EXPORTER_OTLP_HEADERS: "Authorization=Bearer 4113wNO7AFYO336Yn3vj2yvP"
            OTEL_RESOURCE_ATTRIBUTES: "deployment.environment=production"
            OTEL_SERVICE_NAME: "matchmaker"
      secrets:
        matchmaker-secrets:
          type: Opaque
          data:
            REFLECTMULTIPLAYER_ConnectionStrings__MatchmakerDatabase: "Host=opr-postgresql;Database=Matchmaker;Username=matchmaker_service;Password=reflect"
            REFLECTMULTIPLAYER_Mumble__RestApiUsername: "reflect"
            REFLECTMULTIPLAYER_Mumble__RestApiPassword: "murmur-rest-secret-key"

voip:
  mumble-rest:
    reflect-common-chart:
      image:
        tag: develop-latest
        pullPolicy: Always
      configMaps:
        mumble-rest-config:
          data:
            MURMUR_ICE_HOST: "murmur.opr-develop.svc.cluster.local"
            ENABLE_AUTH: "True"
            AUTH_JWT_VALID_ISSUER: https://keycloak.kapistiogroup.com/realms/reflect
            AUTH_JWK_URL: https://keycloak.kapistiogroup.com/realms/reflect/protocol/openid-connect/certs
            AUTH_NAME_CLAIM: preferred_username
            AUTH_UID_OFFSET: "1000"
      secrets:
        mumble-rest-secrets:
          type: Opaque
          data:
            APP_SECRET_KEY: "supersecret"
            USERS: "reflect:murmur-rest-secret-key"
            ICE_SECRET: "murmur-ice-secret-key"
  murmur:
    reflect-common-chart:
      image:
        tag: develop-latest
        pullPolicy: Always
      deployment:
        volumeMounts:
        - name: murmur-files
          mountPath: /etc/murmur
          readOnly: true
        - name: murmur-ssl-cert
          # This path is used for sslCert and sslKey in the murmur.ini file
          mountPath: /etc/opr/murmur-cert
          readOnly: true
      volumes:
      - name: murmur-files
        configMap:
          name: murmur-files
      - name: murmur-ssl-cert
        secret:
          defaultMode: 420
          secretName: voip-develop-tls
    
commonui:
  reflect-common-chart:
    imagePullSecrets:
      - name: regcred-gcp 
    image: 
      repository: us-east1-docker.pkg.dev/unity-solutions-tyndall-prd/docker/reflect-dashboard
      tag: develop-latest
      pullPolicy: Always
    ingress:
      commonui:
        annotations:
          cert-manager.io/cluster-issuer: letsencrypt
        hosts:
          - host: dashboard.kapistiogroup.com
            http:
              paths:
                - backend:
                    service:
                      name: commonui
                      port: 
                        name: http
                  path: /
                  pathType: ImplementationSpecific
        tls:
          - secretName: dashboard-develop-tls
            hosts:
              - dashboard.kapistiogroup.com
    autoscaling:
      enabled: false
    resources: null
    configMaps:
      commonui-config:
        data:
          REACT_APP_PROJECT_SERVER_ENV: develop
          REACT_APP_BIM360_SERVER_ENV: develop
          REACT_APP_PROJECT_SERVER_ADDRESS: 'https://develop.kapistiogroup.com'
          REACT_APP_PROJECT_SERVER_HTTP_ADDRESS: 'https://develop.kapistiogroup.com'
          REACT_APP_IS_ON_PREM_REFLECT: 'true'
          REACT_APP_ON_PREM_REFLECT_ENTERPRISE_DOMAIN: 'BAH OPR'
          REACT_APP_BIM360_SERVER_ENV: local
          REACT_APP_SENTRY_ENABLED: 'false'
          REACT_APP_UNITY_API_ADDRESS: ''
          REACT_APP_UNITY_ID_ADDRESS: ''
          REFLECT_DOMAIN: 'BAH OPR'