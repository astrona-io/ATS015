#!/usr/bin/env bash
# authz-demo : booking-service (service account booking-sa), notification-service
#              (no /admin handler) and a tester client, all with sidecars, under a
#              namespace STRICT PeerAuthentication so workload identities can be
#              trusted by authorization rules.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# It creates nothing the task asks for: those objects are what grading checks.
set -euo pipefail
cd "$(dirname "$0")"

echo "[capstone] Starting workloads"
kubectl apply -f manifests/lab-start.yaml
kubectl apply -f manifests/peerauth.yaml

echo "[capstone] Waiting for the workloads (first run pulls images)"
kubectl -n authz-demo wait --for=condition=Available deploy --all --timeout=600s
kubectl -n authz-demo get pods
echo "[capstone] No AuthorizationPolicy exists - that is the task."
