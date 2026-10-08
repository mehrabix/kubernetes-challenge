#!/usr/bin/env bash
# Shared helpers for the automation scripts.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"
OVERLAY="${OVERLAY:-k8s/overlays/dev}"
IMAGE="${IMAGE:-kubernetes-challenge:1.0.0}"
NAMESPACE="${NAMESPACE:-hello}"
APP_LABEL="app.kubernetes.io/name=hello"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

require() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

require_tools() {
  require minikube
  require kubectl
  require docker
}

minikube_ip() {
  minikube ip -p "$MINIKUBE_PROFILE"
}
