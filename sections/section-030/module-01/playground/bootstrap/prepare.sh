#!/usr/bin/env bash
# OS prep for the "Authenticate End Users With JWT" playground (`ats-015-playground-030-01`).
#
# Environment preparation only — there is no task and no grading. This script:
#   1. puts `istioctl` on the PATH,
#   2. installs the Istio control plane with the `demo` profile,
#   3. applies the module's starting manifests into namespace `jwt-demo`,
#   4. makes sure every pod in that namespace really got a sidecar.
#
# The security objects the module is about (PeerAuthentication,
# RequestAuthentication, AuthorizationPolicy, Gateway TLS, ...) are deliberately
# NOT created here, beyond the preconditions listed in config.yaml. Creating
# them is the point of the module.
set -euo pipefail

ISTIO_VERSION="1.30.5"
NAMESPACE="jwt-demo"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

if ! command -v istioctl >/dev/null 2>&1; then
  WORK="$(mktemp -d)"
  trap 'rm -rf "$WORK"' EXIT
  echo "[playground] Downloading Istio ${ISTIO_VERSION}..."
  (cd "$WORK" && curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION="$ISTIO_VERSION" sh -)
  install -m 0755 "$WORK/istio-${ISTIO_VERSION}/bin/istioctl" "$BIN_DIR/istioctl"
fi
istioctl version --remote=false

echo "[playground] Installing the Istio control plane (demo profile)..."
istioctl install --set profile=demo -y
kubectl -n istio-system rollout status deployment/istiod --timeout=300s
kubectl -n istio-system rollout status deployment/istio-ingressgateway --timeout=300s

# The manifests below are also listed under bootstrap.manifests in config.yaml,
# so they may already be applied by the time this runs. kubectl apply is
# idempotent, and re-applying here covers the case where the pods were created
# before the injection webhook existed.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
apply_manifest() {
  for candidate in \
    "$SCRIPT_DIR/../manifests/$1" \
    "./manifests/$1" \
    "$SCRIPT_DIR/manifests/$1"; do
    if [ -f "$candidate" ]; then
      echo "[playground] Applying $candidate..."
      kubectl apply -f "$candidate"
      return 0
    fi
  done
  echo "[playground] WARNING: manifest $1 not found." >&2
}
apply_manifest "lab-start.yaml"

kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || {
  echo "[playground] ERROR: namespace $NAMESPACE was never created." >&2
  exit 1
}

# Every pod must carry the istio-proxy sidecar. Restart anything that started
# before the webhook was in place, then wait for the namespace to settle.
echo "[playground] Ensuring every workload in $NAMESPACE has a sidecar..."
kubectl -n "$NAMESPACE" rollout restart deployment --all >/dev/null 2>&1 || true
for d in $(kubectl -n "$NAMESPACE" get deployment -o name); do
  kubectl -n "$NAMESPACE" rollout status "$d" --timeout=300s
done

echo "[playground] Ready. Namespace $NAMESPACE:"
kubectl -n "$NAMESPACE" get pods -o wide
