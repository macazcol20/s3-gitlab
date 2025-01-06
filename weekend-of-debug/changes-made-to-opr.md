change all:
- unity.keycloak.local  --> unity-keycloak.kapistiogroup.com
- develop.unity.project-service.local  --> unity-project-service.kapistiogroup.com
- develop-web.unity.project-service.local  --> unity-project-service-web.kapistiogroup.com


- Rabbitmq needs s3 bucket, and it sems to be using minio via this url: https://minio-api-develop.opr.unity.com
  - I will install Minio and assign it the url: https://minio-api-develop.kapistiogroup.com


- Update all tls services to name:  opr-develop-tls