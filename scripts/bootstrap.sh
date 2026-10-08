#!/usr/bin/env bash
# One-command setup: start minikube, enable ingress, build the image, deploy,
# and verify the greeting. Intended for a fresh machine.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_tools

log "Starting minikube (profile: ${MINIKUBE_PROFILE})"
minikube start -p "$MINIKUBE_PROFILE"

log "Enabling the ingress addon"
minikube addons enable ingress -p "$MINIKUBE_PROFILE"

log "Waiting for the ingress controller"
kubectl -n ingress-nginx wait --for=condition=Available \
  deployment/ingress-nginx-controller --timeout=180s

"${REPO_ROOT}/scripts/build-image.sh"
"${REPO_ROOT}/scripts/deploy.sh"
"${REPO_ROOT}/scripts/verify.sh"

log "All set. Try: curl \$(minikube ip -p ${MINIKUBE_PROFILE})/"
