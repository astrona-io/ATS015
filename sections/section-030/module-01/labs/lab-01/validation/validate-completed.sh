#!/usr/bin/env bash
# Grading for ats-015-lab-030-01 - validate tokens, then require one.
# Checks that a RequestAuthentication for the demo issuer and an
# AuthorizationPolicy with requestPrincipals exist in jwt-demo (the old
# resourceExists checks), then sends real requests from the tester pod:
# no token -> 403, bad token -> 401, demo token -> 200, booking-service -> 200.
set -uo pipefail

NS="jwt-demo"
FAIL=0
say() { printf '%s\n' "$*"; }

# Applying the end state and grading it in the same second is a race: pods that
# are being replaced are still listed, and `kubectl exec deploy/x` will happily
# pick the one on its way out - which in these labs is the pod without a sidecar,
# so the call goes out as plaintext and comes back 000. Wait until every
# workload outside the system namespaces is settled before reading behaviour.
settle_dataplane() {
  local i pending
  for i in $(seq 1 60); do
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

TOKEN=$(curl -s --max-time 20 \
  https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/demo.jwt)
if [ -z "${TOKEN:-}" ]; then
  say "FAIL: could not fetch the demo token — this lab needs outbound internet access."
  say "RESULT: FAIL"; exit 1
fi

call() { kubectl -n "$NS" exec deploy/tester -- \
  curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$@" 2>/dev/null; }

# A new policy reaches the proxies a few seconds after it is applied, and
# connections opened before that keep the old rules for a while. Give the
# requirement up to 90 seconds to show up before grading the behaviour.
wait_for_policy() {
  local i
  for i in $(seq 1 45); do
    [ "$(call -X POST http://notification-service/notify)" = "403" ] && return 0
    sleep 2
  done
}
wait_for_policy

say "--- check 1: a RequestAuthentication selects notification-service ---"
if kubectl -n "$NS" get requestauthentication -o yaml 2>/dev/null | grep -q 'testing@secure.istio.io'; then
  say "OK: a RequestAuthentication for the demo issuer exists."
else
  say "FAIL: no RequestAuthentication configured for issuer testing@secure.istio.io."
  FAIL=1
fi

say "--- check 2: a policy requires a request principal ---"
if kubectl -n "$NS" get authorizationpolicy -o yaml 2>/dev/null | grep -q 'requestPrincipals'; then
  say "OK: an AuthorizationPolicy uses requestPrincipals."
else
  say "FAIL: no AuthorizationPolicy uses requestPrincipals — nothing makes a token mandatory."
  FAIL=1
fi

say "--- check 3: a request with no token is refused with 403 ---"
CODE=$(call -X POST http://notification-service/notify)
if [ "$CODE" = "403" ]; then say "OK: no token -> 403"; else
  say "FAIL: no token -> '${CODE:-no response}', expected 403."
  [ "$CODE" = "200" ] && say "      200 means only the RequestAuthentication exists: it validates, it does not require."
  [ "$CODE" = "401" ] && say "      401 means validation rejected it; the requirement should come from authorization."
  FAIL=1
fi

say "--- check 4: an invalid token is rejected with 401 ---"
CODE=$(call -H "Authorization: Bearer invalid" -X POST http://notification-service/notify)
if [ "$CODE" = "401" ]; then say "OK: bad token -> 401"; else
  say "FAIL: bad token -> '${CODE:-no response}', expected 401."
  say "      No RequestAuthentication is validating this workload's traffic."
  FAIL=1
fi

say "--- check 5: the valid demo token is accepted ---"
CODE=$(call -H "Authorization: Bearer $TOKEN" -X POST http://notification-service/notify)
if [ "$CODE" = "200" ]; then say "OK: valid token -> 200"; else
  say "FAIL: valid token -> '${CODE:-no response}', expected 200."
  [ "$CODE" = "401" ] && say "      The issuer string does not match the token's iss exactly, or the JWKS is unreachable."
  [ "$CODE" = "403" ] && say "      The token validated but the rule did not match it — check requestPrincipals."
  FAIL=1
fi

say "--- check 6: booking-service is unaffected ---"
CODE=$(call -X POST http://booking-service/book)
if [ "$CODE" = "200" ]; then say "OK: booking-service still reachable without a token."; else
  say "FAIL: booking-service -> '${CODE:-no response}', expected 200."
  say "      The objects are scoped too widely — they must select notification-service."
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
