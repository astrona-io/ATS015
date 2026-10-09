#!/usr/bin/env bash
# gwauthz-demo : booking-service (no /admin handler), notification-service and a
#                tester client, all with sidecars, plus a Gateway and VirtualService
#                that expose booking.ica.local on port 80 of the ingress gateway.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# It creates nothing the task asks for: those objects are what grading checks.
set -euo pipefail
cd "$(dirname "$0")"

echo "[capstone] Starting workloads"
kubectl apply -f manifests/lab-start.yaml
kubectl apply -f manifests/gateway.yaml

echo "[capstone] Waiting for the workloads (first run pulls images)"
kubectl -n gwauthz-demo wait --for=condition=Available deploy --all --timeout=600s
kubectl -n gwauthz-demo get pods
echo "[capstone] No AuthorizationPolicy exists - that is the task."
