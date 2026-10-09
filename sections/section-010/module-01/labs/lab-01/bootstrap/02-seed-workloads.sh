#!/usr/bin/env bash
# Creates the planet identity-demo (sidecar injection on) with:
#   booking-service-v1       service account booking-sa
#   notification-service-v1  no service account of its own -> default
#   tester                   curl client, no service account of its own -> default
# No PeerAuthentication and no AuthorizationPolicy: writing them is the task.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> identity-demo workloads"
kubectl apply -f manifests/identity-demo.yaml

echo "==> Waiting for the workloads (first run pulls images)"
kubectl wait -n identity-demo --for=condition=Available deploy --all --timeout=600s
kubectl get pods -n identity-demo
echo "==> Lab ats-015-lab-010-01 ready. Nothing the task asks for has been created."
