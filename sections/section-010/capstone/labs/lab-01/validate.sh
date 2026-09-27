#!/usr/bin/env bash
# Grading for CAP015-010 — mesh-wide mTLS, a migrated caller, identity authorization.
set -uo pipefail

FAIL=0
say() { printf '%s\n' "$*"; }

say "--- check 1: a mesh-scoped STRICT policy exists ---"
MESH=$(kubectl -n istio-system get peerauthentication -o json 2>/dev/null \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print(' '.join(i['spec'].get('mtls',{}).get('mode','') for i in d.get('items',[]) if 'selector' not in i['spec']))" 2>/dev/null)
case "$MESH" in
  *STRICT*) say "OK: selector-less STRICT PeerAuthentication in istio-system." ;;
  *) say "FAIL: no mesh-scoped STRICT policy (found: '${MESH:-none}')."
     say "      A policy in identity-demo is a namespace policy, not a mesh one."
     FAIL=1 ;;
esac

say "--- check 2: outside-client was migrated into the mesh ---"
C=$(kubectl -n outside get pods -l app=outside-client -o jsonpath='{.items[*].spec.containers[*].name}' 2>/dev/null)
case "$C" in
  *istio-proxy*) say "OK: outside-client has a sidecar." ;;
  *) say "FAIL: outside-client has no sidecar (containers: '${C:-none}')."
     say "      Labelling the namespace does not touch pods that are already running."
     FAIL=1 ;;
esac

say "--- check 3: the migrated caller still reaches booking-service ---"
CODE=$(kubectl -n outside exec deploy/outside-client -- \
  curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
  -X POST http://booking-service.identity-demo/book 2>/dev/null)
if [ "$CODE" = "200" ]; then say "OK: outside-client -> booking-service -> 200"; else
  say "FAIL: outside-client -> booking-service -> '${CODE:-no response}', expected 200."
  say "      000 means it is still sending plaintext into a STRICT mesh."
  FAIL=1
fi

say "--- check 4: booking-sa may reach notification-service ---"
CODE=$(kubectl -n identity-demo exec deploy/booking-service-v1 -c booking-service -- \
  curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
  -X POST http://notification-service/notify 2>/dev/null)
if [ "$CODE" = "200" ]; then say "OK: booking-service -> notification-service -> 200"; else
  say "FAIL: booking-service -> notification-service -> '${CODE:-no response}', expected 200."
  say "      403 usually means the principal string is wrong."
  FAIL=1
fi

say "--- check 5: another identity may not ---"
CODE=$(kubectl -n identity-demo exec deploy/tester -- \
  curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
  -X POST http://notification-service/notify 2>/dev/null)
if [ "$CODE" = "403" ]; then say "OK: tester -> notification-service -> 403"; else
  say "FAIL: tester -> notification-service -> '${CODE:-no response}', expected 403."
  say "      200 means no ALLOW policy selects notification-service, or the rule is too wide."
  FAIL=1
fi

say "--- check 6: the rule is identity-based ---"
POL=$(kubectl -n identity-demo get authorizationpolicy -o yaml 2>/dev/null)
if printf '%s' "$POL" | grep -q 'principals' && ! printf '%s' "$POL" | grep -q 'spiffe://'; then
  say "OK: an AuthorizationPolicy matches on principals, without the spiffe:// scheme."
else
  say "FAIL: no clean principals-based rule found in identity-demo."
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
