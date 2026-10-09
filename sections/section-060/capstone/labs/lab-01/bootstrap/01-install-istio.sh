#!/usr/bin/env bash
# Puts istioctl 1.30.5 on the machine and installs the Istio control plane.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail

ISTIO_VERSION="1.30.5"

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
  echo "[capstone] Downloading Istio ${ISTIO_VERSION}..."
  (cd "$WORK" && curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION="$ISTIO_VERSION" sh -)
  install -m 0755 "$WORK/istio-${ISTIO_VERSION}/bin/istioctl" "$BIN_DIR/istioctl"
fi
istioctl version --remote=false

echo "[capstone] Installing the Gateway API CRDs (a waypoint is a Gateway API Gateway)..."
kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1 || \
  kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

echo "[capstone] Installing the Istio control plane (ambient profile, no sidecars)..."
istioctl install --set profile=ambient -y
kubectl -n istio-system rollout status deployment/istiod --timeout=300s
kubectl -n istio-system rollout status daemonset/ztunnel --timeout=300s
echo "[capstone] Control plane ready."
