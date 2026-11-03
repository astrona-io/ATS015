#!/usr/bin/env bash
# Creates the lab's starting state in namespace ca-demo (sidecar injection on, STRICT mTLS):
# shuttle (client), probe-long and probe-short (echo servers, one Service each).
# istiod runs with its self-signed CA; no cacerts Secret exists.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Namespace, workloads and STRICT mTLS"
kubectl apply -f manifests/lab-start.yaml

echo "==> Waiting for the workloads (first run pulls images)"
kubectl wait -n ca-demo --for=condition=Available deploy --all --timeout=600s
kubectl get pods -n ca-demo -o wide
echo "==> Lab ats-015-lab-010-04 ready. Nothing the task asks for has been created."
