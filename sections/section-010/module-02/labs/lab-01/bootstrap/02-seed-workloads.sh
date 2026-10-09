#!/usr/bin/env bash
# Creates the lab's starting workloads. Nothing the task asks for is created.
#   mtls-demo  (sidecar injection on)  booking-service-v1, notification-service-v1
#                                      (both serve container port 8084) and a tester client
#   outside    (NO injection)          outside-client: curl without a sidecar, so
#                                      everything it sends is plain text
# No PeerAuthentication exists anywhere, so the mesh default (PERMISSIVE) applies.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Starting workloads"
kubectl apply -f manifests/lab-start.yaml
kubectl apply -f manifests/outside-client.yaml

echo "==> Waiting for pods (first run pulls images, takes a few minutes)"
kubectl wait -n mtls-demo --for=condition=Available deploy --all --timeout=600s
kubectl wait -n outside --for=condition=Available deploy --all --timeout=300s
kubectl get pods -n mtls-demo
kubectl get pods -n outside
echo "==> Lab ats-015-lab-010-02 ready"
