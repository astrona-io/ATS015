#!/usr/bin/env bash
# Grading for LAB015-020-01 — deny-by-default plus two narrow ALLOW rules.
set -uo pipefail

NS="authz-demo"
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

from_tester() {
  kubectl -n "$NS" exec deploy/tester -- \
    curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@" 2>/dev/null
}
from_booking() {
  kubectl -n "$NS" exec deploy/booking-service-v1 -c booking-service -- \
    curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@" 2>/dev/null
}
expect() { # expect <label> <want> <got> [hint]
  if [ "$3" = "$2" ]; then say "OK: $1 -> $3"; else
    say "FAIL: $1 -> '${3:-no response}', expected $2."
    [ -n "${4:-}" ] && say "      $4"
    FAIL=1
  fi
}

say "--- check 1: an ALLOW policy closes the namespace by default ---"
if kubectl -n "$NS" get authorizationpolicy -o name 2>/dev/null | grep -q .; then
  say "OK: at least one AuthorizationPolicy exists in $NS."
else
  say "FAIL: no AuthorizationPolicy in $NS."
  FAIL=1
fi

say "--- check 2: the five graded calls ---"
expect "tester POST /book"    200 "$(from_tester  -X POST http://booking-service/book)" \
  "The booking ALLOW rule is missing or its selector matches no pod."
expect "tester GET /book"     403 "$(from_tester  -X GET  http://booking-service/book)" \
  "The rule permits any operation — it probably has a 'from' but no 'to'."
expect "tester POST /notify"  403 "$(from_tester  -X POST http://notification-service/notify)" \
  "The notification rule matches on namespaces rather than principals; tester shares the namespace."
expect "booking POST /notify" 200 "$(from_booking -X POST http://notification-service/notify)" \
  "A 403 here usually means a wrong principal string (a stray spiffe:// prefix)."
expect "booking GET /notify"  403 "$(from_booking -X GET  http://notification-service/notify)" \
  "The notification rule is not constraining the method."

say "--- check 3: the notification rule is identity-based ---"
POL=$(kubectl -n "$NS" get authorizationpolicy -o yaml 2>/dev/null)
if printf '%s' "$POL" | grep -q 'principals'; then
  if printf '%s' "$POL" | grep -q 'spiffe://'; then
    say "FAIL: a principals value still carries the spiffe:// scheme."
    FAIL=1
  else
    say "OK: a policy matches on principals."
  fi
else
  say "FAIL: no policy in $NS uses 'principals'."
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
