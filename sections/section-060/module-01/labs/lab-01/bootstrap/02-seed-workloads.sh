#!/usr/bin/env bash
# Creates namespace ambient-authz (enrolled in ambient mode), mesh-wide access
# logs (only the waypoint, once created, writes them), and
# notification-service-v1 and the two clients, tester (tester-sa) and
# other-client (other-sa). Creates NONE of the objects the task asks for:
# no AuthorizationPolicy, no waypoint, no use-waypoint label.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Namespace (ambient), access logs and workloads"
kubectl apply -f manifests/namespace.yaml -f manifests/access-logs.yaml
kubectl apply -f manifests/workloads.yaml

echo "==> Waiting for the workloads (first run pulls images)"
kubectl wait -n ambient-authz --for=condition=Available deploy --all --timeout=600s
kubectl get pods -n ambient-authz
