https://repo1.dso.mil/search?nav_source=navbar&repository_ref=main&search=proxyv2&search_code=true
https://registry1.dso.mil/harbor/projects/3/repositories

## install
```sh
mv envoy-proxy io
cd io 
mv chart envoy-proxy
mv envoy-proxy ../
cd ..
rm -rf io
```

```sh
helm -n istio-system install envoy envoy-proxy/
```
 
  
## cluster
Key Points:

- Cluster Name (reflect-project):
This should match the cluster name used in your Envoy routing configuration. Ensure the name reflect-project is referenced correctly elsewhere in your configuration (e.g., in routes or listeners).

- Connect Timeout (connect_timeout: 0.25s):
A 250ms timeout is reasonable for a cluster. However, if connections to the service might take longer, you may want to increase this value to avoid unnecessary timeouts.

- Type (type: logical_dns):
The logical_dns type is appropriate if you're using a DNS name for the service (like argowf-argo-workflows-server.argo.svc.cluster.local).

- HTTP/2 Protocol Options (http2_protocol_options: {}):
This indicates that the cluster supports HTTP/2, which is fine as long as the service you're connecting to supports it.

- Load Balancing Policy (lb_policy: round_robin):
round_robin is a standard and efficient load balancing strategy. Since argowf-argo-workflows-server is a ClusterIP service, Kubernetes will handle the distribution of traffic to the backend pods.

- Hosts:
The hosts section specifies the backend to which Envoy will route traffic. Using argowf-argo-workflows-server.argo.svc.cluster.local with the correct port_value (2746) is correct for this service.

### Validation Steps
- DNS Resolution:

```sh
nslookup argowf-argo-workflows-server.argo.svc.cluster.local
curl http://argowf-argo-workflows-server.argo.svc.cluster.local:2746
```

##  testing proxy for argowf
3. Test Envoy Proxy Access:


## try this
https://repo1.dso.mil/dsop/helm-charts/-/blob/7b1a5f281c474cbe48c6e80298beca36e3d60e4e/stable/envoy/values.yaml