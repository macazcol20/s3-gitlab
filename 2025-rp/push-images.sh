#!/bin/bash

# Directory containing .tar files
IMAGE_DIR="0-images-2025"

# Declare an associative array of tar files and corresponding tags
declare -A IMAGES=(
  ["postgres.tar"]="cafanwii/registry1.dso.mil-ironbank-opensource-postgres-postgresql11:11.20-2"
  ["reflect-annotations.tar"]="cafanwii/reflect-annotations:latest"
  ["reflect-envoy-k8s.tar"]="cafanwii/reflect-envoy-k8s:latest"
  ["reflect-links.tar"]="cafanwii/reflect-links:latest"
  ["reflect-mumble-rest.tar"]="cafanwii/reflect-mumble-rest:latest"
  ["reflect-netcode-init.tar"]="cafanwii/reflect-netcode-init:latest"
  ["reflect-project.tar"]="cafanwii/reflect-project-airgap:latest"
  ["keycloak.tar"]="cafanwii/registry1.dso.mil-ironbank-opensource-keycloak-keycloak:21.1.2"
  ["minio.tar"]="cafanwii/registry1.dso.mil-ironbank-opensource-minio-minio:RELEASE.2023-08-09T23-30-22Z"
  ["rabbitmq.tar"]="cafanwii/registry1.dso.mil-ironbank-bitnami-rabbitmq:3.12.2"
  ["reflect-dashboard.tar"]="cafanwii/reflect-dashboard:latest"
  ["reflect-envoy.tar"]="cafanwii/reflect-envoy:latest"
  ["reflect-matchmaker.tar"]="cafanwii/reflect-matchmaker:latest"
  ["reflect-murmur.tar"]="cafanwii/reflect-murmur:latest"
  ["reflect-netcode.tar"]="cafanwii/reflect-netcode:latest"
  ["reflect-sync.tar"]="cafanwii/reflect-sync:latest"
  ["kibana.tar"]="cafanwii/registry1.dso.mil-ironbank-elastic-kibana-kibana:8.7.0"
  ["fluent-bit.tar"]="cafanwii/registry1.dso.mil-ironbank-opensource-fluent-fluent-bit:2.1.2"
  ["elasticsearch.tar"]="cafanwii/registry1.dso.mil-ironbank/elastic/elasticsearch/elasticsearch:8.7.0"
)

# Navigate to the directory containing the tar files
cd "$IMAGE_DIR" || { echo "Directory $IMAGE_DIR not found! Exiting."; exit 1; }

# Iterate over the tar files and process them
for TAR_FILE in "${!IMAGES[@]}"; do
  if [[ -f "$TAR_FILE" ]]; then
    IMAGE_TAG="${IMAGES[$TAR_FILE]}"
    echo "Processing $TAR_FILE -> $IMAGE_TAG"

    # Load the Docker image
    docker load < "$TAR_FILE"

    # Extract the original image name from the loaded image
    ORIGINAL_IMAGE=$(docker images --format "{{.Repository}}:{{.Tag}}" | head -n 1)

    # Tag the image
    docker tag "$ORIGINAL_IMAGE" "$IMAGE_TAG"

    # Push the image to Docker Hub
    docker push "$IMAGE_TAG"
  else
    echo "File $TAR_FILE not found, skipping..."
  fi
done

echo "All images processed!"
