## Docker
docker login registry1.dso.mil
docker build -t cafanwii/envoy -f Dockerfile.envoy-ironbank .
docker run -d --name envoy-container -p 9901:9901 -p 8080:8080 cafanwii/envoy
docker push cafanwii/envoy
curl -v http://localhost:8080
docker logs -f envoy-container
curl -v http://localhost:9901
nc -zv localhost 8080
curl -v http://localhost:8080
curl -v http://localhost:9901/listeners
curl -v http://localhost:9901/clusters

## deploy to kubernetes
k apply -f .

### Test Envoy Functionality
Accessing Envoy’s Admin API:
To verify Envoy’s operation, you can check the admin API. If you're using a LoadBalancer or Ingress, you can test by querying the admin endpoint externally.
If you deployed Envoy with the service exposed internally, you can access it within your cluster using kubectl port-forward:

```sh
kubectl port-forward svc/envoy-service 9901:9901
```

Then, test by running:

```sh
curl http://localhost:9901/clusters  # List clusters
curl http://localhost:9901/listeners  # List listeners
```
