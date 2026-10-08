#!/usr/bin/env bash
# Render and apply the requested kustomize overlay.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require kubectl

log "Applying ${OVERLAY} (namespace: ${NAMESPACE})"
kubectl apply -k "${REPO_ROOT}/${OVERLAY}"

log "Waiting for the rollout to complete"
kubectl -n "$NAMESPACE" rollout status deployment/hello --timeout=180s
