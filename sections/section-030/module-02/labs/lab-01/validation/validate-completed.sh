#!/usr/bin/env bash
# Grading for "Authorize On A JWT Claim": an admin path gated on a group claim,
# the ordinary path open to any valid token, and nothing open without a token.
# Checks objects first, then sends real traffic from the tester pod.
set -uo pipefail

NS="jwtclaims-demo"
SAMPLES_URL="https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples"
FAILED=0
say() { printf '%s\n' "$*"; }

# Applying the end state and grading it in the same second is a race: pods that
# are being replaced are still listed, and `kubectl exec deploy/x` may pick the
# one on its way out. Wait until every workload outside the system namespaces
# is settled before reading behaviour.
settle_dataplane() {
  local attempt pending
  for attempt in $(seq 1 60); do
    pending=$(kubectl get pods -A \
      --field-selector=status.phase!=Succeeded,status.phase!=Failed \
      -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.deletionTimestamp}{" "}{range .status.containerStatuses[*]}{.ready}{","}{end}{"\n"}{end}' 2>/dev/null \
      | grep -vE '^(kube-system|kube-public|kube-node-lease|local-path-storage|istio-system) ' \
      | awk 'NF>2 || $0 ~ /false/' )
    [ -z "$pending" ] && return 0
    sleep 2
  done
}
settle_dataplane

# --- 0. objects -----------------------------------------------------------------
say "--- check 0: an AuthorizationPolicy exists in $NS ---"
if [ -n "$(kubectl -n "$NS" get authorizationpolicy -o name 2>/dev/null)" ]; then
  say "OK: an AuthorizationPolicy exists in $NS."
else
  say "FAIL: no AuthorizationPolicy found in $NS."
  say "RESULT: FAIL"; exit 1
fi

say "--- check 1: the RequestAuthentication is unchanged ---"
ra_issuer=$(kubectl -n "$NS" get requestauthentication jwt-demo -o jsonpath='{.spec.jwtRules[0].issuer}' 2>/dev/null)
ra_app=$(kubectl -n "$NS" get requestauthentication jwt-demo -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null)
if [ "$ra_issuer" = "testing@secure.istio.io" ] && [ "$ra_app" = "notification-service" ]; then
  say "OK: RequestAuthentication jwt-demo still checks testing@secure.istio.io on notification-service."
else
  say "FAIL: RequestAuthentication jwt-demo is missing or changed (issuer '$ra_issuer', selector app '$ra_app'). Leave it as it was."
  FAILED=1
fi

say "--- check 2: a policy matches on a JWT claim ---"
if kubectl -n "$NS" get authorizationpolicy -o yaml 2>/dev/null | grep -q 'request.auth.claims'; then
  say "OK: an AuthorizationPolicy has a when condition on request.auth.claims."
else
  say "FAIL: no policy matches on request.auth.claims[...]."
  FAILED=1
fi

say "--- check 2b: every rule requires a valid token ---"
# One field per rule, ending in "|": the rule's requestPrincipals, or nothing.
rule_principals=$(kubectl -n "$NS" get authorizationpolicy \
  -o jsonpath='{range .items[*].spec.rules[*]}{.from[*].source.requestPrincipals}{"|"}{end}' 2>/dev/null)
if [ -n "$rule_principals" ] && ! grep -qE '(^|\|)\|' <<<"$rule_principals"; then
  say "OK: every rule carries requestPrincipals."
else
  say "FAIL: at least one rule has no requestPrincipals in from.source. Every rule must require a valid token, not only test a claim."
  FAILED=1
fi

# --- traffic ---------------------------------------------------------------------
TOKEN=$(curl -s --max-time 20 "$SAMPLES_URL/demo.jwt")
GROUPS_TOKEN=$(curl -s --max-time 20 "$SAMPLES_URL/groups-scope.jwt")
if [ -z "${TOKEN:-}" ] || [ -z "${GROUPS_TOKEN:-}" ]; then
  say "FAIL: could not fetch the demo tokens - this lab needs outbound internet access."
  say "RESULT: FAIL"; exit 1
fi

send_signal() { kubectl -n "$NS" exec deploy/tester -- \
  curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$@" 2>/dev/null; }

# A new policy takes up to about a minute to reach live traffic: connections
# that were already open keep the old rules until they close. Wait (up to
# about 90 seconds) until the five requests give the expected answers, then
# grade them one by one.
settle_policy() {
  local attempt
  for attempt in $(seq 1 30); do
    [ "$(send_signal -X POST http://notification-service/notify)" = "403" ] \
      && [ "$(send_signal -H "Authorization: Bearer $TOKEN" -X POST http://notification-service/notify)" = "200" ] \
      && [ "$(send_signal -H "Authorization: Bearer $TOKEN" http://notification-service/admin)" = "403" ] \
      && [ "$(send_signal -H "Authorization: Bearer $GROUPS_TOKEN" http://notification-service/admin)" != "403" ] \
      && return 0
    sleep 3
  done
}
settle_policy

say "--- check 3: a tokenless request is refused ---"
CODE=$(send_signal -X POST http://notification-service/notify)
if [ "$CODE" = "403" ]; then say "OK: no token, POST /notify -> 403"; else
  say "FAIL: no token, POST /notify -> '${CODE:-no response}', expected 403."
  FAILED=1
fi

say "--- check 4: any valid token may POST /notify ---"
CODE=$(send_signal -H "Authorization: Bearer $TOKEN" -X POST http://notification-service/notify)
if [ "$CODE" = "200" ]; then say "OK: demo token, POST /notify -> 200"; else
  say "FAIL: demo token, POST /notify -> '${CODE:-no response}', expected 200."
  FAILED=1
fi

say "--- check 5: a token without the group is refused on /admin ---"
CODE=$(send_signal -H "Authorization: Bearer $TOKEN" http://notification-service/admin)
if [ "$CODE" = "403" ]; then say "OK: demo token, GET /admin -> 403"; else
  say "FAIL: demo token, GET /admin -> '${CODE:-no response}', expected 403."
  say "      Anything other than 403 means the admin rule is not gating on the claim."
  FAILED=1
fi

say "--- check 6: a token with groups=group1 is allowed through to the app ---"
CODE=$(send_signal -H "Authorization: Bearer $GROUPS_TOKEN" http://notification-service/admin)
if [ "$CODE" != "403" ] && [ -n "$CODE" ] && [ "$CODE" != "000" ]; then
  say "OK: groups token, GET /admin -> $CODE (not blocked; the application answered)."
else
  say "FAIL: groups token, GET /admin -> '${CODE:-no response}', expected anything but 403."
  say "      The claim name may be wrong, or the rule may be missing requestPrincipals."
  FAILED=1
fi

say "--- check 7: a tokenless request cannot reach /admin ---"
CODE=$(send_signal http://notification-service/admin)
if [ "$CODE" = "403" ]; then say "OK: no token, GET /admin -> 403"; else
  say "FAIL: no token, GET /admin -> '${CODE:-no response}', expected 403."
  FAILED=1
fi

if [ "$FAILED" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
