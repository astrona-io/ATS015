#!/usr/bin/env bash
# Grading for ats-015-lab-030-01-02 - take the token from the query string.
# Confirms that the probe's RequestAuthentication checks the demo issuer and
# reads the token only from the `token` query parameter, that a DENY policy
# with notRequestPrincipals requires a token and no ALLOW policy selects the
# probe, and - the part that matters - that real signals from the shuttle get:
#   ?token=<demo token>                 -> 200
#   Authorization: Bearer <demo token>  -> 403 (the header is not read)
#   ?token=bad                          -> 401
#   no token                            -> 403

set -u

NS="starfleet"
PROBE="http://probe:8000/headers"
ISSUER="testing@secure.istio.io"

fail() { echo "FAIL: $*"; exit 1; }

# --- 0. the environment is still what the lab handed over -------------------
for d in probe-v1 probe-v2 shuttle; do
  ready=$(kubectl -n "$NS" get deployment "$d" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [[ -n "$ready" && "$ready" -ge 1 ]] || fail "$d - deployment missing or has no ready replicas in $NS. Leave the ships alone"
done
selector=$(kubectl -n "$NS" get service probe -o jsonpath='{.spec.selector.app}' 2>/dev/null)
[[ "$selector" == "probe" ]] || fail "the probe Service must keep selecting app=probe (found '$selector')"

# --- 1. the RequestAuthentication --------------------------------------------
kubectl -n "$NS" get requestauthentication probe-jwt >/dev/null 2>&1 \
  || fail "RequestAuthentication 'probe-jwt' not found in $NS"
ra_app=$(kubectl -n "$NS" get requestauthentication probe-jwt -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null)
[[ "$ra_app" == "probe" ]] || fail "RequestAuthentication probe-jwt must select app: probe (found '$ra_app')"
ra_issuer=$(kubectl -n "$NS" get requestauthentication probe-jwt -o jsonpath='{.spec.jwtRules[0].issuer}' 2>/dev/null)
[[ "$ra_issuer" == "$ISSUER" ]] || fail "the issuer is '$ra_issuer', expected exactly '$ISSUER' (it must match the token's iss claim letter for letter)"
ra_params=$(kubectl -n "$NS" get requestauthentication probe-jwt -o jsonpath='{.spec.jwtRules[0].fromParams[*]}' 2>/dev/null)
[[ " $ra_params " == *" token "* ]] || fail "the RequestAuthentication does not read the token from the 'token' query parameter (fromParams is '$ra_params')"

# --- 2. the DENY policy, and no ALLOW policy ---------------------------------
kubectl -n "$NS" get authorizationpolicy probe-require-jwt >/dev/null 2>&1 \
  || fail "AuthorizationPolicy 'probe-require-jwt' not found in $NS"
ap_action=$(kubectl -n "$NS" get authorizationpolicy probe-require-jwt -o jsonpath='{.spec.action}' 2>/dev/null)
[[ "$ap_action" == "DENY" ]] || fail "probe-require-jwt has action '${ap_action:-ALLOW}', expected DENY"
ap_app=$(kubectl -n "$NS" get authorizationpolicy probe-require-jwt -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null)
[[ "$ap_app" == "probe" ]] || fail "probe-require-jwt must select app: probe (found '$ap_app')"
ap_not=$(kubectl -n "$NS" get authorizationpolicy probe-require-jwt -o jsonpath='{.spec.rules[*].from[*].source.notRequestPrincipals[*]}' 2>/dev/null)
[[ " $ap_not " == *" * "* ]] || fail "probe-require-jwt must refuse signals with notRequestPrincipals: [\"*\"] (found '$ap_not')"

allow_policies=$(kubectl get authorizationpolicy -A \
  -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}={.spec.action}{"\n"}{end}' 2>/dev/null \
  | grep -E '^(starfleet|istio-system)/' | grep -E '=(ALLOW)?$' || true)
[[ -z "$allow_policies" ]] || fail "an ALLOW AuthorizationPolicy exists ($allow_policies). The task asks for the DENY form only"

# --- 3. live signals ------------------------------------------------------------
TOKEN=$(curl -s --max-time 20 \
  https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/demo.jwt)
[[ -n "${TOKEN:-}" ]] || fail "could not download the demo token - this lab needs outbound internet access"

status() {  # $@ = curl args; prints the HTTP status code of one signal from the shuttle
  kubectl -n "$NS" exec deploy/shuttle -- \
    curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@" 2>/dev/null
}

# New rules reach the proxies a few seconds after they are applied, and
# connections opened before that keep the old rules for a while. Wait up to
# 90 seconds until both the query token works and the header token is refused.
settle() {
  local i
  for i in $(seq 1 45); do
    [[ "$(status "$PROBE?token=$TOKEN")" == "200" && \
       "$(status -H "Authorization: Bearer $TOKEN" "$PROBE")" == "403" ]] && return 0
    sleep 2
  done
}
settle

code=$(status "$PROBE?token=$TOKEN")
[[ "$code" == "200" ]] || fail "the demo token in ?token= got '$code', expected 200. A 401 means the issuer or the keys are wrong; a 403 means the token was not read from the query parameter"

code=$(status -H "Authorization: Bearer $TOKEN" "$PROBE")
[[ "$code" == "403" ]] || fail "the demo token in the Authorization header got '$code', expected 403. With fromParams set, the header must not be read"

code=$(status "$PROBE?token=bad")
[[ "$code" == "401" ]] || fail "a bad token in ?token= got '$code', expected 401 from the RequestAuthentication"

code=$(status "$PROBE")
[[ "$code" == "403" ]] || fail "a signal with no token got '$code', expected 403 from the DENY policy"

echo "PASS: the probe reads its token only from ?token=, the DENY policy refuses signals without a valid token, and the codes are 200 (query token), 403 (header token), 401 (bad token), 403 (no token)"
exit 0
