## Test connectivity from the commonui pod to Keycloak:

kubectl exec -n opr-develop -it commonui-867df4ff57-xnqrt -- curl -v https://keycloak.kapistiogroup.com

## error while trying to login to commonui from the browser

```sh
## Could not fetch identity provider for specified enterprise domain.
## his happens because the commonui congitmap does not have the keycloak values
## add below values in the CM

REACT_APP_KEYCLOAK_REALM: reflect  # Replace with your Keycloak realm name
REACT_APP_KEYCLOAK_CLIENT_ID: reflect  # Replace with your Keycloak client ID
REACT_APP_KEYCLOAK_URL: https://keycloak.kapistiogroup.com

k -n opr-develop edit cm commonui-config

## rESTART THE POD

kubectl delete pod -n opr-develop -l app.kubernetes.io/name=commonui
```  