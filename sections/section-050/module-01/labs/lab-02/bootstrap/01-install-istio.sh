#!/usr/bin/env bash
# Installs Istio 1.30.5 (sidecar mode) into the lab cluster with Helm:
#   istio-system   istio-base (CRDs) + istiod (control plane)
#   istio-ingress  ingress gateway, pod label istio=ingress
# It also installs a pinned istioctl 1.30.5: the grader reads the gateway's
# listener with `istioctl proxy-config`.
# Precondition of the lab: every gateway trusts ONE proxy hop in front of it,
# set as the mesh-wide default proxy config
# (meshConfig.defaultConfig.gatewayTopology.numTrustedProxies). istiod is
# installed before the gateway, so the gateway starts with it.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail

ISTIO_VERSION="${ISTIO_VERSION:-1.30.5}"
REPO="https://istio-release.storage.googleapis.com/charts"
# First run pulls images; give Helm time to wait for ready pods.
WAIT=(--wait --timeout 10m)

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

# The grader reads the gateway's listener with `istioctl proxy-config`: pin
# the client to the lab's Istio version. BIN_DIR goes first on PATH above,
# so the pinned binary wins over any system-wide one.
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

echo "==> Istio $ISTIO_VERSION: base (CRDs)"
helm upgrade --install istio-base base --repo "$REPO" --version "$ISTIO_VERSION" \
  -n istio-system --create-namespace "${WAIT[@]}"

echo "==> Istio $ISTIO_VERSION: istiod (gateways trust one proxy hop)"
helm upgrade --install istiod istiod --repo "$REPO" --version "$ISTIO_VERSION" \
  -n istio-system \
  --set meshConfig.defaultConfig.gatewayTopology.numTrustedProxies=1 "${WAIT[@]}"

echo "==> Istio $ISTIO_VERSION: ingress gateway"
# ClusterIP: kind has no load balancer; the learner and the grader port-forward it.
helm upgrade --install istio-ingress gateway --repo "$REPO" --version "$ISTIO_VERSION" \
  -n istio-ingress --create-namespace --set service.type=ClusterIP "${WAIT[@]}"

echo "==> Waiting until the Istio CRDs are registered"
kubectl wait --for=condition=Established crd --all --timeout=120s >/dev/null
echo "==> Istio ready"
