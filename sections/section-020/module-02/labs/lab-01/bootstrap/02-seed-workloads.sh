#!/usr/bin/env bash
# Creates the lab's starting state in namespace deny-demo (sidecar injection on):
# booking-service-v1 (service account booking-sa), notification-service-v1,
# the tester client pod, and a STRICT PeerAuthentication (the precondition, so
# workload identities are verifiable).
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# Creates no AuthorizationPolicy: those are what the task asks for.
set -euo pipefail
cd "$(dirname "$0")"

NAMESPACE="deny-demo"

echo "==> Workloads"
kubectl apply -f manifests/lab-start.yaml

echo "==> STRICT mTLS for $NAMESPACE (precondition)"
kubectl apply -f manifests/peerauthentication-strict.yaml

echo "==> Waiting for the workloads (first run pulls images)"
for dep in $(kubectl -n "$NAMESPACE" get deployment -o name); do
  kubectl -n "$NAMESPACE" rollout status "$dep" --timeout=300s
done
kubectl -n "$NAMESPACE" get pods -o wide
echo "==> Lab ats-015-lab-020-02 ready. Nothing the task asks for has been created."
