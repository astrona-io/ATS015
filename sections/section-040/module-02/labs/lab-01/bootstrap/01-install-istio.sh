#!/usr/bin/env bash
# Installs Istio 1.30.5 into the lab cluster with istioctl and the `demo`
# profile, which includes the istio-ingressgateway Deployment in istio-system.
# This lab keeps the demo profile (and its own small app); the module's
# playground uses Helm instead.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail

ISTIO_VERSION="${ISTIO_VERSION:-1.30.5}"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

# Pin the version rather than accepting whatever istioctl happens to be on the
# machine: a different client installs a different control plane.
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

echo "==> Istio $ISTIO_VERSION: control plane (demo profile)"
istioctl install --set profile=demo -y
kubectl -n istio-system rollout status deployment/istiod --timeout=300s
kubectl -n istio-system rollout status deployment/istio-ingressgateway --timeout=300s
echo "==> Istio ready"
