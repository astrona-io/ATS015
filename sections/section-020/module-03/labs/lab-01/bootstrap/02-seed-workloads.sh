#!/usr/bin/env bash
# Creates the lab's starting state in namespace starfleet (sidecar injection on):
# shuttle and relay (TCP clients, service accounts shuttle and relay), tcp-echo
# (TCP server on ports 9000, 9001 and 9002; its Service lists 9000 and 9001) and a
# STRICT PeerAuthentication (the precondition, so caller identities are verifiable).
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# Creates no AuthorizationPolicy: those are what the task asks for.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Namespace, workloads and STRICT mTLS"
kubectl apply -f manifests/lab-start.yaml

echo "==> Waiting for the workloads (first run pulls images)"
kubectl wait -n starfleet --for=condition=Available deploy --all --timeout=600s
kubectl get pods -n starfleet -o wide
echo "==> Lab ats-015-lab-020-03 ready. Nothing the task asks for has been created."
