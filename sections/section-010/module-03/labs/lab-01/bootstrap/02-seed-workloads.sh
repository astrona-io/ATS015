#!/usr/bin/env bash
# Creates the starting state:
#   - migrate-demo (injected): booking-service-v1, notification-service-v1
#     (container port 8084) and a tester client
#   - outside (NOT injected): outside-client, which calls notification-service
#     with plain signals
# No PeerAuthentication is created: migrate-demo starts in the default
# PERMISSIVE mode, and moving it to STRICT is the task.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail
cd "$(dirname "$0")"

kubectl apply -f manifests/lab-start.yaml
kubectl apply -f manifests/outside-client.yaml

# Every pod in migrate-demo must carry the istio-proxy sidecar. Restart
# anything that started before the injection webhook was ready.
kubectl -n migrate-demo rollout restart deployment --all >/dev/null 2>&1 || true
for d in $(kubectl -n migrate-demo get deployment -o name); do
  kubectl -n migrate-demo rollout status "$d" --timeout=300s
done
kubectl -n outside rollout status deployment/outside-client --timeout=300s

kubectl -n migrate-demo get pods
kubectl -n outside get pods
echo "[lab] No PeerAuthentication exists, and outside-client has no sidecar - that is the task."
