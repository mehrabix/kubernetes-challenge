#!/usr/bin/env bash
# Remove everything this project deployed.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require kubectl

log "Deleting resources from ${OVERLAY}"
kubectl delete -k "${REPO_ROOT}/${OVERLAY}" --ignore-not-found=true
log "Done."
