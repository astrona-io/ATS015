#!/usr/bin/env bash
# Installs Istio 1.30.5 (sidecar mode) into the lab cluster with Helm:
#   istio-system   istio-base (CRDs) + istiod (control plane)
#   istio-ingress  the ingress gateway, pod label istio=ingress, Service type ClusterIP
# It also puts a pinned istioctl 1.30.5 on the PATH: the grader calls it.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail

ISTIO_VERSION="${ISTIO_VERSION:-1.30.5}"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

# Pin the version rather than accepting whatever istioctl happens to be on the
# machine: the grader reads the gateway proxy with it, and the lab is written
# against ${ISTIO_VERSION}. BIN_DIR goes first on PATH above, so the pinned
# binary wins over any system-wide one.
have_version=""
command -v istioctl >/dev/null 2>&1 && \
  have_version=$(istioctl version --remote=false 2>/dev/null | awk '/client version/{print $3}')
if [ "$have_version" != "$ISTIO_VERSION" ]; then
  WORK="$(mktemp -d)"
  trap 'rm -rf "$WORK"' EXIT
  echo "==> Downloading Istio ${ISTIO_VERSION}"
  (cd "$WORK" && curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION="$ISTIO_VERSION" sh -)
  install -m 0755 "$WORK/istio-${ISTIO_VERSION}/bin/istioctl" "$BIN_DIR/istioctl"
fi
istioctl version --remote=false
REPO="https://istio-release.storage.googleapis.com/charts"
# First run pulls images; give Helm time to wait for ready pods.
WAIT=(--wait --timeout 10m)

echo "==> Istio $ISTIO_VERSION: base (CRDs)"
helm upgrade --install istio-base base --repo "$REPO" --version "$ISTIO_VERSION" \
  -n istio-system --create-namespace "${WAIT[@]}"

echo "==> Istio $ISTIO_VERSION: istiod"
helm upgrade --install istiod istiod --repo "$REPO" --version "$ISTIO_VERSION" \
  -n istio-system "${WAIT[@]}"

echo "==> Istio $ISTIO_VERSION: ingress gateway"
# ClusterIP: kind has no load balancer; reach it with kubectl port-forward.
helm upgrade --install istio-ingress gateway --repo "$REPO" --version "$ISTIO_VERSION" \
  -n istio-ingress --create-namespace --set service.type=ClusterIP "${WAIT[@]}"

echo "==> Waiting until the Istio CRDs are registered"
kubectl wait --for=condition=Established crd --all --timeout=120s >/dev/null
echo "==> Istio ready"
