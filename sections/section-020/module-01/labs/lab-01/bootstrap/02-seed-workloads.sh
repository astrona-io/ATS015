#!/usr/bin/env bash
# Creates the lab's starting state in namespace authz-demo (sidecar injection
# on): booking-service (service account booking-sa), notification-service and
# the tester client, plus a STRICT PeerAuthentication so every caller carries
# a checked identity.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# It creates nothing the task asks for: no AuthorizationPolicy.
set -euo pipefail
cd "$(dirname "$0")"

NAMESPACE="authz-demo"

echo "==> Workloads"
kubectl apply -f manifests/lab-start.yaml

echo "==> STRICT mTLS for $NAMESPACE (the precondition)"
kubectl apply -f manifests/peerauthentication-strict.yaml

# Every pod must carry the istio-proxy sidecar. Restart anything that started
# before the injection webhook was in place, then wait for the namespace to
# settle.
echo "==> Making sure every workload in $NAMESPACE has a sidecar"
kubectl -n "$NAMESPACE" rollout restart deployment --all >/dev/null 2>&1 || true
for dep in $(kubectl -n "$NAMESPACE" get deployment -o name); do
  kubectl -n "$NAMESPACE" rollout status "$dep" --timeout=300s
done

kubectl -n "$NAMESPACE" get pods -o wide
echo "==> Lab ats-015-lab-020-01 ready. Nothing the task asks for has been created."
