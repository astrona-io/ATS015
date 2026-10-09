#!/usr/bin/env bash
# tls-demo : booking-service and notification-service (plain HTTP, port 80) and
#            tls-backend, which terminates TLS itself on 8443 with a certificate
#            it generates at startup (CN=secure.ica.local, O=backend).
# /tmp/booking.crt and /tmp/booking.key : certificate material for the
#            terminated hostname. Turning it into a Secret is part of the task.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# It creates nothing the task asks for: those objects are what grading checks.
set -euo pipefail
cd "$(dirname "$0")"

echo "[capstone] Starting workloads"
kubectl apply -f manifests/lab-start.yaml
kubectl apply -f manifests/tls-backend.yaml

echo "[capstone] Waiting for the workloads (first run pulls images)"
kubectl -n tls-demo wait --for=condition=Available deploy --all --timeout=600s
kubectl -n tls-demo get pods

# Certificate MATERIAL is provided; turning it into a Secret in the right
# namespace is part of the task.
if [ ! -f /tmp/booking.crt ] || [ ! -f /tmp/booking.key ]; then
  echo "[capstone] Generating certificate material in /tmp..."
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /tmp/booking.key -out /tmp/booking.crt \
    -subj "/CN=booking.ica.local/O=ica" 2>/dev/null
fi
ls -l /tmp/booking.crt /tmp/booking.key
echo "[capstone] No Gateway, VirtualService or TLS secret exists - that is the task."
