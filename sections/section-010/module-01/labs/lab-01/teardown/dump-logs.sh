#!/usr/bin/env bash
# Best-effort state capture for LAB015-010-01 before the environment is destroyed.
# Runs even on failure; must not block teardown.
set -uo pipefail

echo "[teardown] ats-015-lab-010-01: capturing state"
kubectl get peerauthentication,requestauthentication,authorizationpolicy -A 2>/dev/null || true
kubectl get gateway,virtualservice -A 2>/dev/null || true
kubectl -n identity-demo get pods -o wide 2>/dev/null || true
kubectl -n istio-system logs deploy/istio-ingressgateway --tail=50 2>/dev/null || true
