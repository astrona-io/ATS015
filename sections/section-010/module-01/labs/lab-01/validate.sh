#!/usr/bin/env bash
# Grading for LAB015-010-01 — identity-based authorization on notification-service.
# Behavioural: the right identity gets through, the wrong one does not.
set -uo pipefail

NS="identity-demo"
FAIL=0

say() { printf '%s\n' "$*"; }

say "--- check 1: namespace enforces STRICT mTLS ---"
MODE=$(kubectl -n "$NS" get peerauthentication -o jsonpath='{.items[*].spec.mtls.mode}' 2>/dev/null)
case "$MODE" in
  *STRICT*) say "OK: a PeerAuthentication in $NS is STRICT." ;;
  *) say "FAIL: no STRICT PeerAuthentication in $NS (found: '${MODE:-none}')."; FAIL=1 ;;
esac

say "--- check 2: booking-service (booking-sa) is allowed ---"
CODE=$(kubectl -n "$NS" exec deploy/booking-service-v1 -c booking-service -- \
  curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
  -X POST http://notification-service/notify 2>/dev/null)
if [ "$CODE" = "200" ]; then
  say "OK: booking-service -> notification-service returned 200."
else
  say "FAIL: booking-service -> notification-service returned '${CODE:-no response}', expected 200."
  say "      A 403 here usually means the principal string is wrong (a stray spiffe:// prefix,"
  say "      or the wrong service account). A 000 means mTLS, not authorization."
  FAIL=1
fi

say "--- check 3: tester (default) is refused ---"
CODE=$(kubectl -n "$NS" exec deploy/tester -- \
  curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
  -X POST http://notification-service/notify 2>/dev/null)
if [ "$CODE" = "403" ]; then
  say "OK: tester -> notification-service returned 403."
elif [ "$CODE" = "200" ]; then
  say "FAIL: tester was allowed through. Either no ALLOW policy selects"
  say "      notification-service, or the rule is wider than a single principal."
  FAIL=1
else
  say "FAIL: tester -> notification-service returned '${CODE:-no response}', expected 403."
  say "      A 000 is a transport rejection, which is not what this task asks for."
  FAIL=1
fi

say "--- check 4: the rule matches on identity, not on namespace ---"
if kubectl -n "$NS" get authorizationpolicy -o yaml 2>/dev/null | grep -q 'principals'; then
  if kubectl -n "$NS" get authorizationpolicy -o yaml 2>/dev/null | grep -q 'spiffe://'; then
    say "FAIL: a principals value still carries the spiffe:// scheme."
    FAIL=1
  else
    say "OK: an AuthorizationPolicy matches on principals."
  fi
else
  say "FAIL: no AuthorizationPolicy in $NS uses 'principals'. Matching on namespaces"
  say "      or labels does not satisfy this task."
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
