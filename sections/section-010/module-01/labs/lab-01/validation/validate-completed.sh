#!/usr/bin/env bash
# Grading for ats-015-lab-010-01: identity-based authorization on
# notification-service. Confirms a namespace-wide STRICT PeerAuthentication and
# an AuthorizationPolicy that matches on principals (without spiffe://), then -
# the part that matters - sends live traffic: booking-service (booking-sa) must
# get 200 and tester (default) must get 403.
set -uo pipefail

NS="identity-demo"
URL="http://notification-service/notify"

fail() { echo "FAIL: $*"; exit 1; }

# --- 0. the environment is still what the lab handed over -------------------
for d in booking-service-v1 notification-service-v1 tester; do
  ready=$(kubectl -n "$NS" get deployment "$d" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [[ -n "$ready" && "$ready" -ge 1 ]] || fail "$d - deployment missing or has no ready replicas in $NS. Solve this with Istio objects only"
done
sa=$(kubectl -n "$NS" get deployment booking-service-v1 -o jsonpath='{.spec.template.spec.serviceAccountName}' 2>/dev/null)
[[ "$sa" == "booking-sa" ]] || fail "booking-service-v1 now runs as '${sa:-default}', expected booking-sa. Do not change the Deployments"
sa=$(kubectl -n "$NS" get deployment tester -o jsonpath='{.spec.template.spec.serviceAccountName}' 2>/dev/null)
[[ -z "$sa" || "$sa" == "default" ]] || fail "tester now runs as '$sa', expected default. Do not change the Deployments"

# Wait until no pod in the namespace is still starting or shutting down, so
# `kubectl exec deploy/x` never picks a pod on its way out.
for i in $(seq 1 60); do
  pending=$(kubectl -n "$NS" get pods \
    -o jsonpath='{range .items[*]}{.metadata.deletionTimestamp}{" "}{range .status.containerStatuses[*]}{.ready}{","}{end}{"\n"}{end}' 2>/dev/null \
    | awk 'NF>1 || $0 ~ /false/')
  [[ -z "$pending" ]] && break
  sleep 2
done

# --- 1. STRICT mTLS for the whole namespace -----------------------------------
strict=""
for pa in $(kubectl -n "$NS" get peerauthentication -o name 2>/dev/null); do
  mode=$(kubectl -n "$NS" get "$pa" -o jsonpath='{.spec.mtls.mode}')
  sel=$(kubectl -n "$NS" get "$pa" -o jsonpath='{.spec.selector}')
  [[ "$mode" == "STRICT" && -z "$sel" ]] && strict=1
done
[[ -n "$strict" ]] || fail "no PeerAuthentication in $NS sets mtls.mode STRICT for the whole namespace (without a selector)"

# --- 2. an AuthorizationPolicy that matches on identity -----------------------
policies=$(kubectl -n "$NS" get authorizationpolicy -o yaml 2>/dev/null)
grep -q 'principals' <<<"$policies" \
  || fail "no AuthorizationPolicy in $NS uses 'principals'. Matching on namespaces, labels or addresses does not satisfy this task"
if grep -q 'spiffe://' <<<"$policies"; then
  fail "a principals value still carries the spiffe:// scheme. Istio adds it itself, so this value never matches"
fi

# --- 3. live traffic ------------------------------------------------------------
code_from() {  # $1 = deployment, $2 = container
  kubectl -n "$NS" exec "deploy/$1" -c "$2" -- \
    curl -s -o /dev/null -w '%{http_code}' --max-time 10 -X POST "$URL" 2>/dev/null
}

# New policies reach every proxy within seconds, but connections that were
# already open can keep the old rules for a while. Wait for the expected state.
booking=""; tester=""
for i in $(seq 1 45); do
  booking=$(code_from booking-service-v1 booking-service)
  tester=$(code_from tester tester)
  [[ "$booking" == "200" && "$tester" == "403" ]] && break
  sleep 2
done

if [[ "$booking" != "200" ]]; then
  fail "booking-service -> notification-service returned '${booking:-no response}', expected 200. A 403 usually means the principal string is wrong (a stray spiffe://, or the wrong service account). A 000 means mTLS, not authorization"
fi
if [[ "$tester" == "200" ]]; then
  fail "tester was allowed through. Either no ALLOW policy selects notification-service, or the rule is wider than the booking-sa principal"
elif [[ "$tester" != "403" ]]; then
  fail "tester -> notification-service returned '${tester:-no response}', expected 403. A 000 is a transport rejection, which is not what this task asks for"
fi

echo "PASS: identity-demo enforces STRICT mTLS, the policy matches the booking-sa principal, booking-service gets 200 and tester gets 403"
exit 0
