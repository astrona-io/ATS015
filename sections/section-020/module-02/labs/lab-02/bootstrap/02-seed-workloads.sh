#!/usr/bin/env bash
# Creates the namespace `starfleet` (sidecar injection on), mesh-wide access logs,
# the probe v1/v2 (echo service), the shuttle and fortio clients (two callers
# with two different identities), STRICT mTLS for starfleet, and the starting
# ALLOW policy `probe-allow-fleet` (every starfleet workload may send anything).
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# Creates no DENY policy: that is what the task asks for.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Namespace and access logs"
kubectl apply -f manifests/namespace.yaml -f manifests/access-logs.yaml

echo "==> Probe, shuttle and fortio"
kubectl apply -f manifests/probe.yaml
kubectl apply -f manifests/shuttle.yaml
kubectl apply -n starfleet -f manifests/fortio.yaml

echo "==> STRICT mTLS for starfleet and the starting guest list for the probe"
kubectl apply -f manifests/peerauthentication-strict.yaml
kubectl apply -f manifests/authorizationpolicy-probe-allow-fleet.yaml

echo "==> Waiting for the ships (first run pulls images, takes a few minutes)"
kubectl wait -n starfleet --for=condition=Available deploy --all --timeout=600s
kubectl get pods -n starfleet
echo "==> Lab ats-015-lab-020-02-02 ready"
