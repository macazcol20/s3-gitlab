## sa.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: reflect-project-sa
  namespace: opr-develop
---
## cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: project-config
  namespace: opr-develop
  labels:
    app.kubernetes.io/instance: opr
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: project
    helm.sh/chart: reflect-common-chart-1.0.0
  annotations:
    meta.helm.sh/release-name: opr
    meta.helm.sh/release-namespace: opr-develop
data:
  ASPNETCORE_URLS: http://+:8080  # Updated to bind to port 8080
  OTEL_EXPORTER_OTLP_ENDPOINT: http://apm-server-apm-http:8200
  OTEL_EXPORTER_OTLP_HEADERS: Authorization=Bearer 4113wNO7AFYO336Yn3vj2yvP
  OTEL_RESOURCE_ATTRIBUTES: deployment.environment=production
  OTEL_SERVICE_NAME: project
  REFLECT_CLOUD: OnPrem
  REFLECT_COMPONENT: project
  REFLECT_DOMAIN: BAH OPR
  REFLECT_ENVIRONMENT: Production
  REFLECT_GATEWAY: unity.project-service.local
  REFLECT_TESTRUNNER_WAIT: "1"
  REFLECTPROJECT_LinkSharing__Domain: https://links.kapistiogroup.com
  REFLECTPROJECT_LinkSharing__Path: p/
  REFLECTPROJECT_Prometheus__Enabled: "true"
  REFLECTPROJECT_Security__LicenseValidationStartDate: "2019-11-01T00:00:00Z"
  REFLECTPROJECT_Security__OnPrem__AuthorizeEndpoint: https://kapistiogroup.com/realms/reflect/protocol/openid-connect/auth
  REFLECTPROJECT_Security__OnPrem__ClientId: reflect
  REFLECTPROJECT_Security__OnPrem__ClientIdClaim: azp
  REFLECTPROJECT_Security__OnPrem__Domain: BAH OPR
  REFLECTPROJECT_Security__OnPrem__NameClaim: preferred_username
  REFLECTPROJECT_Security__OnPrem__OAuthJwkUrl: https://kapistiogroup.com/realms/reflect/protocol/openid-connect/certs
  REFLECTPROJECT_Security__OnPrem__OrganizationName: Tyndall Air Force Base
  REFLECTPROJECT_Security__OnPrem__RealmAccessRoleListOwnerOrManagerRole: ReflectOwnerManagerRole
  REFLECTPROJECT_Security__OnPrem__RealmAccessRoleListUserRole: ReflectUserRole
  REFLECTPROJECT_Security__OnPrem__RefreshEndpoint: https://kapistiogroup.com/realms/reflect/protocol/openid-connect/token
  REFLECTPROJECT_Security__OnPrem__RevokeEndpoint: https://kapistiogroup.com/realms/reflect/protocol/openid-connect/revoke
  REFLECTPROJECT_Security__OnPrem__Scope: openid
  REFLECTPROJECT_Security__OnPrem__TokenEndpoint: https://kapistiogroup.com/realms/reflect/protocol/openid-connect/token
  REFLECTPROJECT_Security__OnPrem__UserInfoEndpoint: https://kapistiogroup.com/realms/reflect/protocol/openid-connect/userinfo
  REFLECTPROJECT_Security__OnPrem__ValidIssuer: https://kapistiogroup.com/realms/reflect
  REFLECTPROJECT_Security__OnPrem__ViewerProtocol: reflect
  REFLECTPROJECT_ServerEndpoint__Host: 0.0.0.0
  REFLECTPROJECT_ServiceEndpoints__Annotations__HttpAddress: https://annotations-develop.opr.kapistiogroup.com
  REFLECTPROJECT_ServiceEndpoints__MatchMaker__GrpcAddress: https://matchmaker-develop.opr.kapistiogroup.com
  REFLECTPROJECT_ServiceEndpoints__MatchMaker__HttpAddress: https://matchmaker-develop.opr.kapistiogroup.com
  REFLECTPROJECT_ServiceEndpoints__ProjectServer__GrpcAddress: https://develop.opr.kapistiogroup.com
  REFLECTPROJECT_ServiceEndpoints__ProjectServer__GrpcWebAddress: https://web-develop.opr.kapistiogroup.com
  REFLECTPROJECT_ServiceEndpoints__ProjectServer__HttpAddress: https://develop.opr.kapistiogroup.com
  REFLECTPROJECT_ServiceEndpoints__VoipServer__OtherServerAddress: mumble://voip-develop.opr.kapistiogroup.com:30000
  REFLECTPROJECT_SyncServer__Cloud__Address: https://sync-develop.opr.kapistiogroup.com
  REFLECTPROJECT_SyncServer__Cloud__SupportsDecimation: "true"
  URLS: http://+:8080  # Updated to match ASPNETCORE_URLS
---
## deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: project
  namespace: opr-develop
  labels:
    app.kubernetes.io/instance: opr
    app.kubernetes.io/name: project
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/instance: opr
      app.kubernetes.io/name: project
  template:
    metadata:
      labels:
        app.kubernetes.io/instance: opr
        app.kubernetes.io/name: project
    spec:
      imagePullSecrets:
        - name: regcred-gcp
      containers:
      - name: project
        image: us-east1-docker.pkg.dev/unity-solutions-tyndall-prd/docker/reflect-project:develop-latest
        imagePullPolicy: Always
        envFrom:
        - secretRef:
            name: project-external-secrets
        - configMapRef:
            name: project-config
        env:
        - name: ASPNETCORE_URLS
          value: http://+:8080 # Updated to bind to port 8080 instead of 80
        ports:
        - containerPort: 10010
          name: grpc
          protocol: TCP
        - containerPort: 8080 # Updated to match the new internal port
          name: http
          protocol: TCP
        - containerPort: 1234
          name: prom-publisher
          protocol: TCP
        livenessProbe:
          exec:
            command:
            - /bin/grpc_health_probe
            - -addr=:10010
          failureThreshold: 3
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 1
        readinessProbe:
          exec:
            command:
            - /bin/grpc_health_probe
            - -addr=:10010
          failureThreshold: 3
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 1
        securityContext:
          capabilities:
            add: ["NET_BIND_SERVICE"] # Add this only if binding to port 80 is required
      - name: envoy
        image: us-east1-docker.pkg.dev/unity-solutions-tyndall-prd/docker/reflect-envoy-k8s:develop-latest
        imagePullPolicy: Always
        resources: {}
        securityContext:
          allowPrivilegeEscalation: false
          runAsUser: 2
      dnsPolicy: ClusterFirst
      hostname: reflect-project
      serviceAccountName: reflect-project-sa
      terminationGracePeriodSeconds: 30
---
## svc.yahl
apiVersion: v1
kind: Service
metadata:
  name: project
  namespace: opr-develop
  labels:
    app.kubernetes.io/instance: opr
    app.kubernetes.io/name: project
spec:
  clusterIP: 10.109.135.58
  ports:
  - name: prom-publisher
    port: 1234
    protocol: TCP
    targetPort: 1234
  - name: grpc
    port: 10010
    protocol: TCP
    targetPort: 10010
  - name: grpc-web
    port: 8080
    protocol: TCP
    targetPort: 8080
  - name: http
    port: 80
    protocol: TCP
    targetPort: 8080 # Map external port 80 to internal port 8080
  - name: grpc-web-admin
    port: 9901
    protocol: TCP
    targetPort: 9901
  selector:
    app.kubernetes.io/instance: opr
    app.kubernetes.io/name: project
  type: ClusterIP
