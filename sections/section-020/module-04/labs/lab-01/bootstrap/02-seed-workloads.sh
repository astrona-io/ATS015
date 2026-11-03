#!/usr/bin/env bash
# Creates the lab's starting state in namespace starfleet (sidecar injection on):
# shuttle (client), probe (HTTP echo server, port 8000), ext-authz (the Istio sample
# external authorizer, HTTP on 8000 and gRPC on 9000, no sidecar) and a STRICT
# PeerAuthentication. astrona runs this script with KUBECONFIG pointed at the lab cluster.
# Creates no extension provider and no AuthorizationPolicy: those are the task.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Namespace, workloads and STRICT mTLS"
kubectl apply -f manifests/lab-start.yaml

echo "==> Waiting for the workloads (first run pulls images)"
kubectl wait -n starfleet --for=condition=Available deploy --all --timeout=600s
kubectl get pods -n starfleet -o wide
echo "==> Lab ats-015-lab-020-04 ready. Nothing the task asks for has been created."
