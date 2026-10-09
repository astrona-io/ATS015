#!/usr/bin/env bash
# Installs Istio 1.30.5 into the lab cluster with istioctl (demo profile):
#   istio-system   istiod + istio-ingressgateway (pod label istio=ingressgateway)
# Then gives the ingress gateway ONE trusted proxy hop (numTrustedProxies: 1).
# That is a precondition of the lab: the learner writes policy, not an install.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail

ISTIO_VERSION="${ISTIO_VERSION:-1.30.5}"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

# Pin the istioctl version: a different client installs a different control plane.
have_version=""
command -v istioctl >/dev/null 2>&1 && \
  have_version=$(istioctl version --remote=false 2>/dev/null | awk '/client version/{print $3}')
if [ "$have_version" != "$ISTIO_VERSION" ]; then
  WORK="$(mktemp -d)"
  trap 'rm -rf "$WORK"' EXIT
  echo "==> Downloading istioctl ${ISTIO_VERSION}"
  (cd "$WORK" && curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION="$ISTIO_VERSION" sh -)
  install -m 0755 "$WORK/istio-${ISTIO_VERSION}/bin/istioctl" "$BIN_DIR/istioctl"
fi
istioctl version --remote=false

echo "==> Istio $ISTIO_VERSION: demo profile"
istioctl install --set profile=demo -y
kubectl -n istio-system rollout status deployment/istiod --timeout=300s
kubectl -n istio-system rollout status deployment/istio-ingressgateway --timeout=300s

# numTrustedProxies must reach the gateway's OWN proxy config.
# meshConfig.gatewayTopology.numTrustedProxies is not a MeshConfig field: it is
# accepted and ignored, the gateway gets no xffNumTrustedHops, and every
# remoteIpBlocks rule silently matches nothing. The pod annotation works
# (checked in the listener dump: xffNumTrustedHops 1).
echo "==> Ingress gateway: trust one proxy hop in front of it"
kubectl -n istio-system patch deployment istio-ingressgateway -p \
  '{"spec":{"template":{"metadata":{"annotations":{"proxy.istio.io/config":"{\"gatewayTopology\":{\"numTrustedProxies\":1}}"}}}}}'
kubectl -n istio-system rollout status deployment/istio-ingressgateway --timeout=300s
echo "==> Istio ready"
