#!/usr/bin/env bash
# Grading for LAB015-060-01 — identity and method enforced at the waypoint.
set -uo pipefail

NS="ambient-authz"
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

say "--- check 4: the wrong identity is refused ---"
# Once the service has a waypoint, every connection to it arrives from the
# waypoint's own identity, so ztunnel at the destination cannot tell one client
# from another. The identity rule is enforced by the waypoint instead, and the
# refusal therefore arrives as a 403 rather than a dropped connection. A 000
# here would mean the waypoint is not in the path at all.
CODE=$(call other-client POST)
if [ "$CODE" = "403" ]; then
  say "OK: other-client was refused by the waypoint (403)."
else
  say "FAIL: other-client -> '${CODE:-no response}', expected 403."
  say "      The policy must name tester-sa, and attach to the Service with targetRefs."
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
