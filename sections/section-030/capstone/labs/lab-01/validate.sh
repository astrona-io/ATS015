#!/usr/bin/env bash
# Grading for CAP015-030 — validate, require, and split by claim.
set -uo pipefail

NS="jwtclaims-demo"
BASE="https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples"
FAIL=0
say() { printf '%s\n' "$*"; }

TOKEN=$(curl -s --max-time 20 "$BASE/demo.jwt")
TOKEN_GROUP=$(curl -s --max-time 20 "$BASE/groups-scope.jwt")
if [ -z "${TOKEN:-}" ] || [ -z "${TOKEN_GROUP:-}" ]; then
  say "FAIL: could not fetch the demo tokens — this lab needs outbound internet access."
  say "RESULT: FAIL"; exit 1
fi
call() { kubectl -n "$NS" exec deploy/tester -- curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$@" 2>/dev/null; }
expect() { if [ "$3" = "$2" ]; then say "OK: $1 -> $3"; else
  say "FAIL: $1 -> '${3:-no response}', expected $2."; [ -n "${4:-}" ] && say "      $4"; FAIL=1; fi; }

say "--- check 1: validation is configured for the demo issuer ---"
kubectl -n "$NS" get requestauthentication -o yaml 2>/dev/null | grep -q 'testing@secure.istio.io' \
  && say "OK: a RequestAuthentication for the demo issuer exists." \
  || { say "FAIL: no RequestAuthentication for issuer testing@secure.istio.io."; FAIL=1; }

say "--- check 2: a token is required, and a claim is matched ---"
POL=$(kubectl -n "$NS" get authorizationpolicy -o yaml 2>/dev/null)
printf '%s' "$POL" | grep -q 'requestPrincipals' \
  && say "OK: a rule uses requestPrincipals." \
  || { say "FAIL: no rule uses requestPrincipals — nothing makes a token mandatory."; FAIL=1; }
printf '%s' "$POL" | grep -q 'request.auth.claims' \
  && say "OK: a rule matches on a JWT claim." \
  || { say "FAIL: no rule matches on request.auth.claims[...]."; FAIL=1; }

say "--- check 3: the six graded requests ---"
expect "no token, POST /notify"    403 "$(call -X POST http://notification-service/notify)" \
  "200 means only validation is configured; 401 means validation refused it instead of authorization."
expect "bad token, POST /notify"   401 "$(call -H 'Authorization: Bearer invalid' -X POST http://notification-service/notify)" \
  "No RequestAuthentication is validating this workload."
expect "plain token, POST /notify" 200 "$(call -H "Authorization: Bearer $TOKEN" -X POST http://notification-service/notify)" \
  "401 means the issuer string or the JWKS is wrong."
expect "plain token, GET /admin"   403 "$(call -H "Authorization: Bearer $TOKEN" http://notification-service/admin)" \
  "This token has no groups claim, so the admin rule must not match."
expect "no token, GET /admin"      403 "$(call http://notification-service/admin)" \
  "A when condition without requestPrincipals can be reached with no token."

CODE=$(call -H "Authorization: Bearer $TOKEN_GROUP" http://notification-service/admin)
if [ "$CODE" != "403" ] && [ -n "$CODE" ] && [ "$CODE" != "000" ]; then
  say "OK: groups token, GET /admin -> $CODE (allowed through; the application answered)."
else
  say "FAIL: groups token, GET /admin -> '${CODE:-no response}', expected anything but 403."
  say "      The claim name may be wrong — decode the token and compare."
  FAIL=1
fi

say "--- check 4: booking-service is unaffected ---"
expect "no token, POST /book" 200 "$(call -X POST http://booking-service/book)" \
  "The objects are scoped too widely — they must select notification-service."

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
