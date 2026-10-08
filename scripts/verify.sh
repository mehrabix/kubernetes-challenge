#!/usr/bin/env bash
# Verify the end-to-end path: curl the minikube IP and expect "Hello <NAME>!".
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require kubectl
require minikube

IP="$(minikube_ip)"
EXPECTED_NAME="$(kubectl -n "$NAMESPACE" get configmap hello-config -o jsonpath='{.data.NAME}')"
log "minikube IP: ${IP}"
log "Expected greeting: Hello ${EXPECTED_NAME}!"

for i in $(seq 1 30); do
  BODY="$(curl -s --max-time 5 "http://${IP}/" || true)"
  if [ "$BODY" = "Hello ${EXPECTED_NAME}!" ]; then
    log "OK: ${BODY}"
    exit 0
  fi
  sleep 2
done

die "unexpected response from http://${IP}/: '${BODY:-<empty>}'"
