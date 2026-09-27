#!/usr/bin/env bash
# Grading for LAB015-060-01 — L4 with ztunnel, L7 with a waypoint.
set -uo pipefail

NS="ambient-authz"
FAIL=0
say() { printf '%s\n' "$*"; }
call() { # call <deployment> <method> -> status
  kubectl -n "$NS" exec "deploy/$1" -- \
    curl -s -o /dev/null -w '%{http_code}' --max-time 10 -X "$2" \
    http://notification-service/notify 2>/dev/null; }

say "--- check 1: a waypoint exists and is programmed ---"
if kubectl -n "$NS" get gateway.gateway.networking.k8s.io -o name 2>/dev/null | grep -q .; then
  say "OK: a Gateway API Gateway exists in $NS."
else
  say "FAIL: no waypoint Gateway in $NS. An L7 rule has nothing to enforce it."
  FAIL=1
fi

say "--- check 2: traffic is enrolled through the waypoint ---"
USE=$(kubectl get namespace "$NS" -o jsonpath='{.metadata.labels.istio\.io/use-waypoint}' 2>/dev/null)
SVCUSE=$(kubectl -n "$NS" get service notification-service -o jsonpath='{.metadata.labels.istio\.io/use-waypoint}' 2>/dev/null)
if [ -n "${USE:-}" ] || [ -n "${SVCUSE:-}" ]; then
  say "OK: use-waypoint enrolment is set (namespace='${USE:-}', service='${SVCUSE:-}')."
else
  say "FAIL: nothing is enrolled through the waypoint."
  say "      Deploying a waypoint and routing traffic through it are two separate steps."
  FAIL=1
fi

say "--- check 3: the L7 policy attaches with targetRefs ---"
if kubectl -n "$NS" get authorizationpolicy -o yaml 2>/dev/null | grep -q 'targetRefs'; then
  say "OK: an AuthorizationPolicy uses targetRefs."
else
  say "FAIL: no AuthorizationPolicy uses targetRefs."
  say "      L7 policy attaches to the waypoint in front of a service, not to pods."
  FAIL=1
fi

say "--- check 4: the wrong identity is refused at the connection ---"
CODE=$(call other-client POST)
if [ "$CODE" = "000" ] || [ -z "$CODE" ]; then
  say "OK: other-client was refused at the transport (L4)."
elif [ "$CODE" = "403" ]; then
  say "FAIL: other-client got 403, so it is being refused at L7 by the waypoint."
  say "      The task asks for an identity rule ztunnel can enforce at L4."
  FAIL=1
else
  say "FAIL: other-client -> '$CODE', expected a refused connection."
  FAIL=1
fi

say "--- check 5: the allowed identity may POST ---"
CODE=$(call tester POST)
if [ "$CODE" = "200" ]; then say "OK: tester POST -> 200"; else
  say "FAIL: tester POST -> '${CODE:-no response}', expected 200."
  say "      000 means the L4 principal string is wrong; 403 means the L7 rule excludes POST."
  FAIL=1
fi

say "--- check 6: the allowed identity may not GET ---"
CODE=$(call tester GET)
if [ "$CODE" = "403" ]; then
  say "OK: tester GET -> 403 (the waypoint enforced the method rule)."
else
  say "FAIL: tester GET -> '${CODE:-no response}', expected 403."
  say "      200 is the ambient trap: the L7 policy applied cleanly and nothing enforced it."
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
