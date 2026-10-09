#!/usr/bin/env bash
# Creates the namespace `jwt-demo` (sidecar injection on) with booking-service-v1,
# notification-service-v1 and the tester client pod.
# Creates NONE of the objects the task asks for - those are what grading checks.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Namespace and workloads"
kubectl apply -f manifests/jwt-demo.yaml

echo "==> Waiting for the workloads (first run pulls images, takes a few minutes)"
kubectl wait -n jwt-demo --for=condition=Available deploy --all --timeout=600s
kubectl get pods -n jwt-demo
echo "==> Lab ats-015-lab-030-01 ready. Nothing the task asks for has been created."
