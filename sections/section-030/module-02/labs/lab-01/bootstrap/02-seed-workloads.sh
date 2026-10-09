#!/usr/bin/env bash
# Creates namespace jwtclaims-demo (sidecar injection on) with booking-service,
# notification-service (POST /notify, no /admin handler) and the tester client,
# then the RequestAuthentication for Istio's sample issuer on
# notification-service. The RequestAuthentication is a precondition, not the
# task. Nothing the task asks for (an AuthorizationPolicy) is created.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail
cd "$(dirname "$0")"

NAMESPACE="jwtclaims-demo"

echo "==> Namespace and workloads"
kubectl apply -f manifests/lab-start.yaml

echo "==> RequestAuthentication (precondition)"
kubectl apply -f manifests/requestauthentication-jwt-demo.yaml

echo "==> Waiting for the workloads (first run pulls images, takes a few minutes)"
kubectl wait -n "$NAMESPACE" --for=condition=Available deploy --all --timeout=600s
kubectl get pods -n "$NAMESPACE"
