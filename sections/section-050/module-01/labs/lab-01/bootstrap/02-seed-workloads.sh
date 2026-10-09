#!/usr/bin/env bash
# Creates the lab's own small app in namespace gwauthz-demo (sidecar injection on):
# booking-service-v1 (serves /book), notification-service-v1 and a tester pod,
# plus a Gateway and VirtualService for booking.ica.local on port 80.
# Creates NO AuthorizationPolicy: writing it is the task.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail
cd "$(dirname "$0")"

NAMESPACE="gwauthz-demo"

echo "==> Workloads and the booking.ica.local Gateway"
kubectl apply -f manifests/lab-start.yaml
kubectl apply -f manifests/gateway.yaml

# Restart anything that started before the injection webhook was ready, so
# every pod really carries a sidecar.
kubectl -n "$NAMESPACE" rollout restart deployment --all >/dev/null 2>&1 || true
for dep in $(kubectl -n "$NAMESPACE" get deployment -o name); do
  kubectl -n "$NAMESPACE" rollout status "$dep" --timeout=600s
done

kubectl -n "$NAMESPACE" get pods
echo "==> Nothing the task asks for has been created."
