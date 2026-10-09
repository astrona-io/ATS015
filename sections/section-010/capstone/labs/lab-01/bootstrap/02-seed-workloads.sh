#!/usr/bin/env bash
# identity-demo : booking-service (service account booking-sa), notification-service
#                 and a tester client, all with sidecars.
# outside       : outside-client, a curl pod with NO sidecar that calls
#                 booking-service in plain text.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# It creates nothing the task asks for: those objects are what grading checks.
set -euo pipefail
cd "$(dirname "$0")"

echo "[capstone] Starting workloads"
kubectl apply -f manifests/lab-start.yaml
kubectl apply -f manifests/outside-client.yaml

echo "[capstone] Waiting for the workloads (first run pulls images)"
kubectl -n identity-demo wait --for=condition=Available deploy --all --timeout=600s
kubectl -n outside wait --for=condition=Available deploy --all --timeout=600s
kubectl -n identity-demo get pods
kubectl -n outside get pods
echo "[capstone] No PeerAuthentication or AuthorizationPolicy exists - that is the task."
