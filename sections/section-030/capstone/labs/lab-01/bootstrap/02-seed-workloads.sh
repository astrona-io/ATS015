#!/usr/bin/env bash
# jwtclaims-demo : booking-service, notification-service (no /admin handler)
#                  and a tester client, all with sidecars. No RequestAuthentication
#                  and no AuthorizationPolicy.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# It creates nothing the task asks for: those objects are what grading checks.
set -euo pipefail
cd "$(dirname "$0")"

echo "[capstone] Starting workloads"
kubectl apply -f manifests/lab-start.yaml

echo "[capstone] Waiting for the workloads (first run pulls images)"
kubectl -n jwtclaims-demo wait --for=condition=Available deploy --all --timeout=600s
kubectl -n jwtclaims-demo get pods
echo "[capstone] No RequestAuthentication or AuthorizationPolicy exists - that is the task."
