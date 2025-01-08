## NOTE TO SELF
All TLS are installed on mainframe server

### Install certbot
sudo apt install certbot
sudo certbot certificates

## Install cert manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml
kubectl get pods --namespace cert-manager




```sh
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: macfenty@gmail.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

```sh
kubectl get clusterissuer letsencrypt-prod -n cert-manager
```

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: keycloak-tls
  namespace: keycloak
spec:
  dnsNames:
  - "*.kapistiogroup.com"
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt-prod
  secretName: keycloak-tls
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak-ingress
  namespace: keycloak
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - "*.kapistiogroup.com"
    secretName: keycloak-tls
  rules:
  - host: keycloak.kapistiogroup.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: keycloak-http
            port:
              number: 80
```

kubectl describe certificate keycloak-tls -n keycloak
kubectl get secret -n opr-develop
kubectl logs -l app=cert-manager -n cert-manager
dig *.kapistiogroup.com
dig keycloak.kapistiogroup.com
dig TXT _acme-challenge.re-lux.club
dig A 10.0.0.


<!-- 
***use this same command to generate and update cert***

```sh
sudo certbot certonly --manual -d *.re-lux.club --agree-tos --manual-public-ip-logging-ok --preferred-challenges dns-01 --server https://acme-v02.api.letsencrypt.org/directory --email=macfenty@gmail.com --rsa-key-size 4096
```

sudo certbot --nginx -d *.re-lux.club -d www.re-lux.club
sudo certbot --nginx -d iwordee.com -d www.iwordee.com
***OUTPUT - Use to create a TXT record in Godaddy***

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
_acme-challenge.re-lux.club 

FX0CvK-ZfZoP3tRLS2Waq-Vzkt43J-EbhK5y7-VK4W8

***OUTPUT AFTER hitting Enter***

Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/re-lux.club/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/re-lux.club/privkey.pem
This certificate expires on 2024-07-04.
These files will be updated when the certificate renews.

NEXT STEPS:
- This certificate will not be renewed automatically. Autorenewal of --manual certificates requires the use of an authentication hook script (--manual-auth-hook) but one was not provided. To renew this certificate, repeat this same certbot command before the certificate's expiry date.

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
If you like Certbot, please consider supporting our work by:
 * Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
 * Donating to EFF:                    https://eff.org/donate-le
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


### NOTE: use Sudo as below, create a secret yaml ```sosotech-io-tls-secret.yaml```

```sh
sudo kubectl create secret tls gateway-certs --cert=/etc/letsencrypt/live/re-lux.club/fullchain.pem --key=/etc/letsencrypt/live/re-lux.club/privkey.pem -n istio-system --dry-run=client -o yaml > sosotechnologies-tls-secret.yaml
```

#### create namespace and deploy secret

```sh
kubectl create ns istio-system
kubectl apply -f sosotechnologies-tls-secret.yaml
``` -->
