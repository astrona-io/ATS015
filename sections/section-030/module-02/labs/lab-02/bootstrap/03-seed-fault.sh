#!/usr/bin/env bash
# Applies the starting state: the AuthorizationPolicy `probe-access`, with two
# faults the learner must find:
#   - the /headers rule requires a token, so the public path is not public
#   - the admin rule compares the claim `group`, which no token has
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> AuthorizationPolicy probe-access (starting state)"
kubectl apply -f manifests/authorizationpolicy-probe-access-broken.yaml
