So after installing the terraform resources,
I updated the files with the roles and applied

do it with the private hostedzone

## apply the cluster issuer
```sh
k apply -f clusterIssuer.yaml
```

## NOTE:
I didn't even need to update the ingress publicIP to DNS because it already recorgnizes it

