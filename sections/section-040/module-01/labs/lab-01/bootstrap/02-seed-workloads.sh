#!/usr/bin/env bash
# Creates tls-demo with booking-service and notification-service (both behind
# Services on port 80) and a tester client, and leaves certificate material for
# booking.ica.local in /tmp. No TLS Secret, no Gateway and no VirtualService are
# created - making them is the task.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail
cd "$(dirname "$0")"

NAMESPACE="tls-demo"

echo "[lab] Applying the starting workloads..."
kubectl apply -f manifests/lab-start.yaml

# Certificate MATERIAL is provided; turning it into a Secret in the right
# namespace is part of the task.
if [ ! -f /tmp/booking.crt ] || [ ! -f /tmp/booking.key ]; then
  echo "[lab] Generating certificate material in /tmp..."
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /tmp/booking.key -out /tmp/booking.crt \
    -subj "/CN=booking.ica.local/O=ica" 2>/dev/null
fi
ls -l /tmp/booking.crt /tmp/booking.key

# Every pod must carry the istio-proxy sidecar. Restart anything that started
# before the injection webhook was in place, then wait for the namespace to settle.
echo "[lab] Ensuring every workload in $NAMESPACE has a sidecar..."
kubectl -n "$NAMESPACE" rollout restart deployment --all >/dev/null 2>&1 || true
for dep in $(kubectl -n "$NAMESPACE" get deployment -o name); do
  kubectl -n "$NAMESPACE" rollout status "$dep" --timeout=300s
done

kubectl -n "$NAMESPACE" get pods -o wide
echo "[lab] Nothing the task asks for has been created."
