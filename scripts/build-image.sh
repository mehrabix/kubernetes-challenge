#!/usr/bin/env bash
# Build the container image and make it available to minikube.
#
# The image is built with the *host* Docker daemon (which can reach a registry)
# and then loaded into the cluster, so no registry push is required. This works
# with every minikube runtime, including containerd.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require docker
require minikube

log "Building image ${IMAGE} with the host Docker daemon"
docker build -t "$IMAGE" "$REPO_ROOT"

log "Loading ${IMAGE} into minikube (profile: ${MINIKUBE_PROFILE})"
minikube image load "$IMAGE" -p "$MINIKUBE_PROFILE"

log "Deployment will use imagePullPolicy: IfNotPresent, so the local image is used."
