#!/usr/bin/env bash
# Creates the planet `starfleet` (sidecar injection on), mesh-wide access logs
# and the shuttle client. The shuttle calls httpbin.org on the internet, so the
# lab needs outbound internet access.
# No ServiceEntry, DestinationRule or VirtualService: writing them is the task.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Namespace and access logs"
kubectl apply -f manifests/namespace.yaml -f manifests/access-logs.yaml

echo "==> The shuttle"
kubectl apply -f manifests/shuttle.yaml

echo "==> Waiting for the shuttle (first run pulls images, takes a few minutes)"
kubectl wait -n starfleet --for=condition=Available deploy --all --timeout=600s
kubectl get pods -n starfleet

echo "==> Checking outbound internet from the shuttle"
if kubectl exec -n starfleet deploy/shuttle -- curl -s -o /dev/null --max-time 15 https://httpbin.org/get; then
  echo "==> httpbin.org is reachable"
else
  echo "==> WARNING: the shuttle cannot reach https://httpbin.org. This lab needs outbound internet access."
fi
echo "==> Lab ats-015-lab-040-04-01 ready"
