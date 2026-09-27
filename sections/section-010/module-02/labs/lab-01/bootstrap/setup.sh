#!/usr/bin/env bash
# Bootstrap for LAB015-010-02 — Enforce mTLS At Three Scopes
# Pre-work only. This installs Istio and the starting workloads; it deliberately
# creates NONE of the objects the task asks for — those are what grading checks.
set -euo pipefail

ISTIO_VERSION="1.30.5"
NAMESPACE="mtls-demo"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

if ! command -v istioctl >/dev/null 2>&1; then
  WORK="$(mktemp -d)"
  trap 'rm -rf "$WORK"' EXIT
  echo "[bootstrap] Downloading Istio ${ISTIO_VERSION}..."
  (cd "$WORK" && curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION="$ISTIO_VERSION" sh -)
  install -m 0755 "$WORK/istio-${ISTIO_VERSION}/bin/istioctl" "$BIN_DIR/istioctl"
fi
istioctl version --remote=false

echo "[bootstrap] Installing the Istio control plane (demo profile)..."
istioctl install --set profile=demo -y
kubectl -n istio-system rollout status deployment/istiod --timeout=300s
kubectl -n istio-system rollout status deployment/istio-ingressgateway --timeout=300s

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
apply_manifest "outside-client.yaml"

kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || {
  echo "[bootstrap] ERROR: namespace $NAMESPACE was never created." >&2
  exit 1
}

echo "[bootstrap] Ensuring every workload in $NAMESPACE has a sidecar..."
kubectl -n "$NAMESPACE" rollout restart deployment --all >/dev/null 2>&1 || true
for dep in $(kubectl -n "$NAMESPACE" get deployment -o name); do
  kubectl -n "$NAMESPACE" rollout status "$dep" --timeout=300s
done

echo "[bootstrap] Ready. Namespace $NAMESPACE:"
kubectl -n "$NAMESPACE" get pods -o wide
echo "[bootstrap] Nothing the task asks for has been created."
