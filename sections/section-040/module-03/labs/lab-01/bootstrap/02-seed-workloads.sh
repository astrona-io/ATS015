#!/usr/bin/env bash
# passthrough-demo: one backend that ends TLS itself.
#   tls-backend  nginx that makes its OWN self-signed certificate at start-up
#                (CN=secure.ica.local, O=backend) and serves HTTPS on 8443
# No Gateway, no VirtualService and no TLS secret - that is the task.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail
cd "$(dirname "$0")"

NAMESPACE="passthrough-demo"

echo "==> Namespace $NAMESPACE and tls-backend"
kubectl apply -f manifests/tls-backend.yaml

# Every pod must carry the istio-proxy sidecar. Restart anything that started
# before the injection webhook was in place, then wait for it to settle.
kubectl -n "$NAMESPACE" rollout restart deployment --all >/dev/null 2>&1 || true
for dep in $(kubectl -n "$NAMESPACE" get deployment -o name); do
  kubectl -n "$NAMESPACE" rollout status "$dep" --timeout=300s
done

kubectl -n "$NAMESPACE" get pods -o wide
echo "==> Lab ats-015-lab-040-03 ready. Nothing the task asks for has been created."
