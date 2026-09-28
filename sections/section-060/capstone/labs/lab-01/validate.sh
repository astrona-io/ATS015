#!/usr/bin/env bash
# Grading for CAP015-060 — one requirement split across ztunnel and a waypoint.
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
call() { # call <deployment> <method> <path>
  kubectl -n "$NS" exec "deploy/$1" -- \
    curl -s -o /dev/null -w '%{http_code}' --max-time 10 -X "$2" \
    "http://notification-service$3" 2>/dev/null; }

say "--- check 1: a waypoint exists ---"
kubectl -n "$NS" get gateway.gateway.networking.k8s.io -o name 2>/dev/null | grep -q . \
  && say "OK: a Gateway API Gateway exists in $NS." \
  || { say "FAIL: no waypoint Gateway in $NS — the L7 half has nothing to enforce it."; FAIL=1; }

say "--- check 2: traffic is enrolled through it ---"
USE=$(kubectl get namespace "$NS" -o jsonpath='{.metadata.labels.istio\.io/use-waypoint}' 2>/dev/null)
SVCUSE=$(kubectl -n "$NS" get service notification-service -o jsonpath='{.metadata.labels.istio\.io/use-waypoint}' 2>/dev/null)
if [ -n "${USE:-}" ] || [ -n "${SVCUSE:-}" ]; then
  say "OK: use-waypoint enrolment is set (namespace='${USE:-}', service='${SVCUSE:-}')."
else
  say "FAIL: nothing is enrolled through the waypoint. Creating it and routing to it are two steps."
  FAIL=1
fi

say "--- check 3: both attachment forms are used ---"
POL=$(kubectl -n "$NS" get authorizationpolicy -o yaml 2>/dev/null)
printf '%s' "$POL" | grep -q 'targetRefs' \
  && say "OK: a policy attaches with targetRefs." \
  || { say "FAIL: no policy uses targetRefs — L7 policy attaches to the waypoint, not to pods."; FAIL=1; }
printf '%s' "$POL" | grep -q 'selector' \
  && say "OK: a policy attaches with a label selector." \
  || { say "FAIL: no policy uses a selector — the L4 half should attach to the workloads."; FAIL=1; }

say "--- check 4: ztunnel is holding a workload-scoped policy ---"
if istioctl ztunnel-config policy --namespace "$NS" 2>/dev/null | grep -qi 'workload'; then
  say "OK: ztunnel holds a workload-scoped policy."
else
  say "FAIL: ztunnel holds no workload-scoped policy for $NS."
  say "      The identity rule must be enforceable at L4."
  FAIL=1
fi

say "--- check 5: the four graded calls ---"
CODE=$(call other-client POST /notify)
if [ "$CODE" = "000" ] || [ -z "$CODE" ]; then
  say "OK: other-client POST /notify -> refused at the transport."
elif [ "$CODE" = "403" ]; then
  say "FAIL: other-client got 403 — it is being refused at L7, not at the connection."
  FAIL=1
else
  say "FAIL: other-client POST /notify -> '$CODE', expected a refused connection."
  FAIL=1
fi

CODE=$(call tester POST /notify)
[ "$CODE" = "200" ] && say "OK: tester POST /notify -> 200" \
  || { say "FAIL: tester POST /notify -> '${CODE:-no response}', expected 200."
       say "      000 means the L4 principal is wrong; 403 means the L7 rule excludes it."; FAIL=1; }

CODE=$(call tester GET /notify)
[ "$CODE" = "403" ] && say "OK: tester GET /notify -> 403" \
  || { say "FAIL: tester GET /notify -> '${CODE:-no response}', expected 403."
       say "      200 is the ambient trap: the L7 policy applied and nothing enforced it."; FAIL=1; }

CODE=$(call tester POST /admin)
[ "$CODE" = "403" ] && say "OK: tester POST /admin -> 403" \
  || { say "FAIL: tester POST /admin -> '${CODE:-no response}', expected 403."
       say "      The L7 rule is not constraining the path."; FAIL=1; }

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
