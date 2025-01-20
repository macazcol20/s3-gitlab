# Reflect Helm Charts

All Helm charts use [reflect-common-chart](./reflect-common-chart) as the base.

The templates for all shared Kubernetes Resources (Deployments, Ingress, etc.) are stored in [reflect-common-chart/templates](./reflect-common-chart/templates)

## Creation of a new service

To create a new service called `annotations`:
1. Create a directory at `Helm/Reflect/annotations` for your new service. Add a `Chart.yaml` file with the following:

```
apiVersion: v2
name: annotations
version: 1.0.0
dependencies:
- name: reflect-common-chart
  version: 1.3.9
  repository: gs://reflect-helm-prd

```

2. Create a `values.yaml` file which contains the configuration that will be common to each environment.
3. For environment specific configuration and secrets, create `envs/gcp/{test,stg,prd}.yaml`. See any service charts for examples.
4. Add the `helm-deploy-annotations` and `helm-diff-annotations` targets to [HelmReflect.mk](../../Makefiles/HelmReflect.mk)
5. Update [image-tags.yaml](./image-tags.yaml) with the service name as well as the image tag to be used for the deployment to each environment

## Deployment of Helm chart

Run `helm-deploy-<service>` to deploy a Helm chart to the cluster. Make sure the correct environment is checked out first (use `work-on-test` to deploy to test, for example.).

You can run `helm-diff-<service>` before running `helm-deploy-<service>` to see what changes the deployment will bring.
