#!/usr/bin/env bash
# Creates the namespace `starfleet` (sidecar injection on), mesh-wide access logs,
# the shuttle client and the probe v1/v2 echo service, then the
# RequestAuthentication `probe-jwt` for Istio's sample issuer on the probe.
# The RequestAuthentication is correct and is not part of the fault.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Namespace and access logs"
kubectl apply -f manifests/namespace.yaml -f manifests/access-logs.yaml

echo "==> Shuttle and probe"
kubectl apply -f manifests/shuttle.yaml
kubectl apply -f manifests/probe.yaml

echo "==> RequestAuthentication on the probe"
kubectl apply -f manifests/requestauthentication-probe.yaml

echo "==> Waiting for the ships (first run pulls images, takes a few minutes)"
kubectl wait -n starfleet --for=condition=Available deploy --all --timeout=600s
kubectl get pods -n starfleet
