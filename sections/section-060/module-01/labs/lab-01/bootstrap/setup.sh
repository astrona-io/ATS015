#!/usr/bin/env bash
# Bootstrap for LAB015-060-01 — Enforce L4 And L7 Policy In Ambient Mode
# Pre-work only. This installs Istio and the starting workloads; it deliberately
# creates NONE of the objects the task asks for — those are what grading checks.
set -euo pipefail

ISTIO_VERSION="1.30.5"
NAMESPACE="ambient-authz"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

# Pin the version rather than accepting whatever istioctl happens to be on the
# machine: a different client installs a different control plane, and the whole
# course is written against ${ISTIO_VERSION}. BIN_DIR goes first on PATH above,
# so the pinned binary wins over any system-wide one.
have_version=""
command -v istioctl >/dev/null 2>&1 && \
  have_version=$(istioctl version --remote=false 2>/dev/null | awk '/client version/{print $3}')
if [ "$have_version" != "$ISTIO_VERSION" ]; then
  WORK="$(mktemp -d)"
  trap 'rm -rf "$WORK"' EXIT
  echo "[bootstrap] Downloading Istio ${ISTIO_VERSION}..."
  (cd "$WORK" && curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION="$ISTIO_VERSION" sh -)
  install -m 0755 "$WORK/istio-${ISTIO_VERSION}/bin/istioctl" "$BIN_DIR/istioctl"
fi
istioctl version --remote=false

echo "[bootstrap] Installing the Gateway API CRDs (a waypoint is a Gateway API Gateway)..."
kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1 || \
  kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

echo "[bootstrap] Installing the Istio control plane (ambient profile)..."
istioctl install --set profile=ambient -y
kubectl -n istio-system rollout status deployment/istiod --timeout=300s
kubectl -n istio-system rollout status daemonset/ztunnel --timeout=300s

# The manifests below are also listed under bootstrap.manifests in config.yaml,
# so they may already be applied. kubectl apply is idempotent, and re-applying
# covers pods created before the injection webhook existed.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
apply_manifest() {
  for c in "$SCRIPT_DIR/../manifests/$1" "./manifests/$1" "$SCRIPT_DIR/manifests/$1"; do
    if [ -f "$c" ]; then echo "[bootstrap] Applying $c..."; kubectl apply -f "$c"; return 0; fi
  done
  echo "[bootstrap] WARNING: manifest $1 not found." >&2
}
apply_manifest "lab-start.yaml"

kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || {
  echo "[bootstrap] ERROR: namespace $NAMESPACE was never created." >&2
  exit 1
}

# Enrolment is a precondition: the task is the policy, not the install.
echo "[bootstrap] Enrolling $NAMESPACE in ambient mode..."
kubectl label namespace "$NAMESPACE" istio.io/dataplane-mode=ambient --overwrite
for dep in $(kubectl -n "$NAMESPACE" get deployment -o name); do
  kubectl -n "$NAMESPACE" rollout status "$dep" --timeout=300s
done

echo "[bootstrap] Ready. Namespace $NAMESPACE:"
kubectl -n "$NAMESPACE" get pods -o wide
echo "[bootstrap] Nothing the task asks for has been created."
