#!/usr/bin/env bash
# Grading for "Fix The Claim Rule": the probe's access model must work again.
#   /headers          public (no token needed)
#   GET /get          any valid token
#   /anything/admin   only a token whose groups claim contains group1
# Checks the objects first, then sends live signals from the shuttle.
set -u

NS="starfleet"
SAMPLES_URL="https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples"
PROBE="http://probe:8000"

fail() { echo "FAIL: $*"; exit 1; }

# --- 0. the environment is still what the lab handed over -------------------
for deployment in probe-v1 probe-v2 shuttle; do
  ready=$(kubectl -n "$NS" get deployment "$deployment" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [[ -n "$ready" && "$ready" -ge 1 ]] || fail "$deployment - deployment missing or has no ready replicas in $NS. Leave the ships alone: the fix belongs in the AuthorizationPolicy"
done

ra_issuer=$(kubectl -n "$NS" get requestauthentication probe-jwt -o jsonpath='{.spec.jwtRules[0].issuer}' 2>/dev/null)
ra_app=$(kubectl -n "$NS" get requestauthentication probe-jwt -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null)
[[ "$ra_issuer" == "testing@secure.istio.io" && "$ra_app" == "probe" ]] \
  || fail "RequestAuthentication probe-jwt is missing or changed (issuer '$ra_issuer', selector app '$ra_app'). It was correct - leave it as it was"

# --- 1. the AuthorizationPolicy ----------------------------------------------
policies=$(kubectl -n "$NS" get authorizationpolicy -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
[[ "$policies" == "probe-access" ]] \
  || fail "AuthorizationPolicies in $NS are [$policies], expected exactly [probe-access]. Fix the existing policy instead of adding or removing one"

action=$(kubectl -n "$NS" get authorizationpolicy probe-access -o jsonpath='{.spec.action}' 2>/dev/null)
[[ -z "$action" || "$action" == "ALLOW" ]] || fail "probe-access has action '$action', expected ALLOW"

keys=$(kubectl -n "$NS" get authorizationpolicy probe-access \
  -o jsonpath='{range .spec.rules[*]}{range .when[*]}{.key}={.values}{"\n"}{end}{end}' 2>/dev/null)
grep -q '^request.auth.claims\[groups\]=.*group1' <<<"$keys" \
  || fail "probe-access has no when condition on request.auth.claims[groups] with group1 (found: $(tr '\n' ' ' <<<"$keys")). Decode the groups token and compare the claim name"
if grep -q '^request.auth.claims\[group\]=' <<<"$keys"; then
  fail "probe-access still compares request.auth.claims[group]. No token has a claim with that name"
fi

# --- 2. live signals ------------------------------------------------------------
TOKEN=$(curl -s --max-time 20 "$SAMPLES_URL/demo.jwt")
GROUPS_TOKEN=$(curl -s --max-time 20 "$SAMPLES_URL/groups-scope.jwt")
[[ -n "$TOKEN" && -n "$GROUPS_TOKEN" ]] || fail "could not fetch the sample tokens - this lab needs outbound internet access"

send_signal() { kubectl -n "$NS" exec deploy/shuttle -- \
  curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@" 2>/dev/null; }

# Connections that were already open keep the old rules until they close
# (up to about a minute). Wait until both fixed paths answer before grading.
settle() {
  local attempt
  for attempt in $(seq 1 60); do
    [[ "$(send_signal "$PROBE/headers")" == "200" ]] \
      && [[ "$(send_signal -H "Authorization: Bearer $GROUPS_TOKEN" "$PROBE/anything/admin")" == "200" ]] \
      && return 0
    sleep 2
  done
}
settle

expect() {  # $1 = expected code, $2 = description, rest = curl args
  local want="$1" what="$2"; shift 2
  local got
  got=$(send_signal "$@")
  [[ "$got" == "$want" ]] || fail "$what -> '${got:-no response}', expected $want"
  echo "OK: $what -> $got"
}

expect 200 "no token, /headers (public path)"                     "$PROBE/headers"
expect 403 "no token, GET /get"                                    "$PROBE/get"
expect 200 "demo token, GET /get"                                  -H "Authorization: Bearer $TOKEN" "$PROBE/get"
expect 403 "no token, /anything/admin"                             "$PROBE/anything/admin"
expect 403 "demo token (no groups claim), /anything/admin"         -H "Authorization: Bearer $TOKEN" "$PROBE/anything/admin"
expect 200 "groups token (group1), /anything/admin"                -H "Authorization: Bearer $GROUPS_TOKEN" "$PROBE/anything/admin"

echo "PASS: /headers is public, /get needs a valid token, /anything/admin needs a token with group1, and probe-access compares request.auth.claims[groups]"
exit 0
