#!/usr/bin/env bash
# ambient-authz : notification-service, tester (service account tester-sa) and
#                 other-client (service account other-sa), enrolled in ambient mode.
#                 No sidecars, no waypoint, no AuthorizationPolicy.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# It creates nothing the task asks for: those objects are what grading checks.
set -euo pipefail
cd "$(dirname "$0")"

echo "[capstone] Starting workloads"
kubectl apply -f manifests/lab-start.yaml

# Enrolment is a precondition: the task is the policy and the waypoint, not
# the data plane.
echo "[capstone] Enrolling ambient-authz in ambient mode"
kubectl label namespace ambient-authz istio.io/dataplane-mode=ambient --overwrite

echo "[capstone] Waiting for the workloads (first run pulls images)"
kubectl -n ambient-authz wait --for=condition=Available deploy --all --timeout=600s
kubectl -n ambient-authz get pods
echo "[capstone] No waypoint and no AuthorizationPolicy exists - that is the task."
