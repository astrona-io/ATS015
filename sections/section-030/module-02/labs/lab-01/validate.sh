#!/usr/bin/env bash
# Grading for LAB015-030-02 — claim-based authorization on an admin path.
set -uo pipefail

NS="jwtclaims-demo"
BASE="https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples"
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

TOKEN=$(curl -s --max-time 20 "$BASE/demo.jwt")
TOKEN_GROUP=$(curl -s --max-time 20 "$BASE/groups-scope.jwt")
if [ -z "${TOKEN:-}" ] || [ -z "${TOKEN_GROUP:-}" ]; then
  say "FAIL: could not fetch the demo tokens — this lab needs outbound internet access."
  say "RESULT: FAIL"; exit 1
fi

call() { kubectl -n "$NS" exec deploy/tester -- \
  curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$@" 2>/dev/null; }

say "--- check 1: a policy matches on a JWT claim ---"
if kubectl -n "$NS" get authorizationpolicy -o yaml 2>/dev/null | grep -q 'request.auth.claims'; then
  say "OK: an AuthorizationPolicy has a when condition on request.auth.claims."
else
  say "FAIL: no policy matches on request.auth.claims[...]."
  FAIL=1
fi

say "--- check 2: a tokenless request is refused ---"
CODE=$(call -X POST http://notification-service/notify)
if [ "$CODE" = "403" ]; then say "OK: no token, POST /notify -> 403"; else
  say "FAIL: no token, POST /notify -> '${CODE:-no response}', expected 403."
  FAIL=1
fi

say "--- check 3: any valid token may POST /notify ---"
CODE=$(call -H "Authorization: Bearer $TOKEN" -X POST http://notification-service/notify)
if [ "$CODE" = "200" ]; then say "OK: demo token, POST /notify -> 200"; else
  say "FAIL: demo token, POST /notify -> '${CODE:-no response}', expected 200."
  FAIL=1
fi

say "--- check 4: a token without the group is refused on /admin ---"
CODE=$(call -H "Authorization: Bearer $TOKEN" http://notification-service/admin)
if [ "$CODE" = "403" ]; then say "OK: demo token, GET /admin -> 403"; else
  say "FAIL: demo token, GET /admin -> '${CODE:-no response}', expected 403."
  say "      Anything other than 403 means the admin rule is not gating on the claim."
  FAIL=1
fi

say "--- check 5: a token with groups=group1 is allowed through to the app ---"
CODE=$(call -H "Authorization: Bearer $TOKEN_GROUP" http://notification-service/admin)
if [ "$CODE" != "403" ] && [ -n "$CODE" ] && [ "$CODE" != "000" ]; then
  say "OK: groups token, GET /admin -> $CODE (not blocked; the application answered)."
else
  say "FAIL: groups token, GET /admin -> '${CODE:-no response}', expected anything but 403."
  say "      The claim name may be wrong, or the rule may be missing requestPrincipals."
  FAIL=1
fi

say "--- check 6: a tokenless request cannot reach /admin ---"
CODE=$(call http://notification-service/admin)
if [ "$CODE" = "403" ]; then say "OK: no token, GET /admin -> 403"; else
  say "FAIL: no token, GET /admin -> '${CODE:-no response}', expected 403."
  say "      A when condition without requestPrincipals can be reached without a token."
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
