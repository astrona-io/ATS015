#!/usr/bin/env bash
# Grading for ats-015-lab-060-01 - identity and method enforced at a waypoint.
# Checks the objects first (a waypoint Gateway that is programmed, the
# use-waypoint enrolment, an AuthorizationPolicy with targetRefs), then sends
# real traffic: other-client POST -> 403, tester POST -> 200, tester GET -> 403.
set -uo pipefail

NS="ambient-authz"
FAIL=0
say() { printf '%s\n' "$*"; }

# Applying the end state and grading it in the same second is a race: pods
# that are being replaced are still listed, and the waypoint may not have its
# configuration yet. Wait until every workload outside the system namespaces is
# settled before reading behaviour.
settle_workloads() {
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
settle_workloads

call() { # call <deployment> <method> -> status code
  kubectl -n "$NS" exec "deploy/$1" -- \
    curl -s -o /dev/null -w '%{http_code}' --max-time 10 -X "$2" \
    http://notification-service/notify 2>/dev/null; }

say "--- check 1: a waypoint Gateway exists and is programmed ---"
WAYPOINTS=$(kubectl -n "$NS" get gateway.gateway.networking.k8s.io \
  -o jsonpath='{range .items[?(@.spec.gatewayClassName=="istio-waypoint")]}{.metadata.name}{" "}{end}' 2>/dev/null)
if [ -z "${WAYPOINTS// /}" ]; then
  say "FAIL: no Gateway with gatewayClassName istio-waypoint in $NS. An L7 rule has nothing to enforce it."
  FAIL=1
else
  PROGRAMMED=""
  for gw in $WAYPOINTS; do
    for i in $(seq 1 30); do
      st=$(kubectl -n "$NS" get gateway.gateway.networking.k8s.io "$gw" \
        -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
      [ "$st" = "True" ] && { PROGRAMMED="$gw"; break; }
      sleep 2
    done
    [ -n "$PROGRAMMED" ] && break
  done
  if [ -n "$PROGRAMMED" ]; then
    say "OK: waypoint '$PROGRAMMED' exists and is programmed."
  else
    say "FAIL: waypoint Gateway [$WAYPOINTS] exists but is not Programmed=True."
    FAIL=1
  fi
fi

say "--- check 2: traffic is enrolled through the waypoint ---"
USE=$(kubectl get namespace "$NS" -o jsonpath='{.metadata.labels.istio\.io/use-waypoint}' 2>/dev/null)
SVCUSE=$(kubectl -n "$NS" get service notification-service -o jsonpath='{.metadata.labels.istio\.io/use-waypoint}' 2>/dev/null)
if [ -n "${USE:-}" ] || [ -n "${SVCUSE:-}" ]; then
  say "OK: use-waypoint enrolment is set (namespace='${USE:-}', service='${SVCUSE:-}')."
else
  say "FAIL: nothing is enrolled through the waypoint."
  say "      Creating a waypoint and sending traffic through it are two separate steps."
  FAIL=1
fi

say "--- check 3: the L7 policy attaches with targetRefs ---"
if kubectl -n "$NS" get authorizationpolicy -o yaml 2>/dev/null | grep -q 'targetRefs'; then
  say "OK: an AuthorizationPolicy uses targetRefs."
else
  say "FAIL: no AuthorizationPolicy in $NS uses targetRefs."
  say "      L7 policy attaches to the waypoint in front of a service, not to pods."
  FAIL=1
fi

# Policy changes take up to about a minute to reach live traffic (open
# connections keep the old rule). Retry the three calls for up to 90 s until
# they all match, then grade what the last round returned.
OTHER_POST=""; TESTER_POST=""; TESTER_GET=""
for i in $(seq 1 30); do
  OTHER_POST=$(call other-client POST)
  TESTER_POST=$(call tester POST)
  TESTER_GET=$(call tester GET)
  [ "$OTHER_POST" = "403" ] && [ "$TESTER_POST" = "200" ] && [ "$TESTER_GET" = "403" ] && break
  sleep 3
done

say "--- check 4: the wrong identity is refused ---"
# Once the service has a waypoint, the identity rule is enforced by the
# waypoint, so the refusal arrives as a 403 rather than a closed connection.
# 000 here means the waypoint is not in the path, or a pod-level rule refuses
# the waypoint's own identity.
CODE="$OTHER_POST"
if [ "$CODE" = "403" ]; then
  say "OK: other-client was refused by the waypoint (403)."
else
  say "FAIL: other-client -> '${CODE:-no response}', expected 403."
  say "      The policy must name tester-sa, and attach to the Service with targetRefs."
  FAIL=1
fi

say "--- check 5: the allowed identity may POST ---"
CODE="$TESTER_POST"
if [ "$CODE" = "200" ]; then say "OK: tester POST -> 200"; else
  say "FAIL: tester POST -> '${CODE:-no response}', expected 200."
  say "      403 means the rule excludes POST or names the wrong principal."
  say "      000 or 503 often means a pod-level rule refuses the waypoint's identity."
  FAIL=1
fi

say "--- check 6: the allowed identity may not GET ---"
CODE="$TESTER_GET"
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
