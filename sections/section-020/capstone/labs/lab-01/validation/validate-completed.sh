#!/usr/bin/env bash
# Grading for CAP015-020 — deny-by-default, two narrow ALLOW rules, one DENY backstop.
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
from_tester()  { kubectl -n "$NS" exec deploy/tester -- curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@" 2>/dev/null; }
from_booking() { kubectl -n "$NS" exec deploy/booking-service-v1 -c booking-service -- curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@" 2>/dev/null; }
expect() { if [ "$3" = "$2" ]; then say "OK: $1 -> $3"; else
  say "FAIL: $1 -> '${3:-no response}', expected $2."; [ -n "${4:-}" ] && say "      $4"; FAIL=1; fi; }

say "--- check 1: the policy set has the right shape ---"
ACTIONS=$(kubectl -n "$NS" get authorizationpolicy -o jsonpath='{.items[*].spec.action}' 2>/dev/null)
case "$ACTIONS" in *DENY*) say "OK: a DENY policy exists." ;;
  *) say "FAIL: no DENY policy in $NS. An ALLOW cannot be a backstop."; FAIL=1 ;; esac
POL=$(kubectl -n "$NS" get authorizationpolicy -o yaml 2>/dev/null)
printf '%s' "$POL" | grep -q 'principals' \
  && say "OK: a rule matches on principals." \
  || { say "FAIL: no rule uses principals."; FAIL=1; }
printf '%s' "$POL" | grep -q 'spiffe://' \
  && { say "FAIL: a principals value still carries the spiffe:// scheme."; FAIL=1; } \
  || true

say "--- check 2: the permissive /admin policy is still in place ---"
# JSON, not YAML: python3 ships a JSON parser, while PyYAML may be missing.
if kubectl -n "$NS" get authorizationpolicy -o json 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin) or {}
hit=False
for i in d.get('items',[]):
    if i['spec'].get('action','ALLOW')!='ALLOW': continue
    for r in i['spec'].get('rules') or []:
        for to in r.get('to') or []:
            for p in (to.get('operation',{}).get('paths') or []):
                if p.startswith('/admin'): hit=True
sys.exit(0 if hit else 1)"; then
  say "OK: an ALLOW policy explicitly permits an /admin path (and is overridden)."
else
  say "FAIL: no ALLOW policy names /admin. Step 3 of the task asks for one, as the proof."
  FAIL=1
fi

say "--- check 3: the six graded calls ---"
# A connection opened before the last change can keep the old rules for up to
# about a minute. Retry for up to 90 seconds until all six calls give the
# expected code, then judge the last round.
run_calls() {
  GOT1=$(from_tester  -X POST http://booking-service/book)
  GOT2=$(from_tester  -X GET  http://booking-service/book)
  GOT3=$(from_tester  -X POST http://notification-service/notify)
  GOT4=$(from_booking -X POST http://notification-service/notify)
  GOT5=$(from_tester  http://notification-service/admin)
  GOT6=$(from_tester  http://notification-service/admin/users)
}
for i in $(seq 1 18); do
  run_calls
  [ "$GOT1 $GOT2 $GOT3 $GOT4 $GOT5 $GOT6" = "200 403 403 200 403 403" ] && break
  sleep 5
done
expect "tester POST /book"        200 "$GOT1" \
  "The booking ALLOW rule is missing or its selector matches no pod."
expect "tester GET /book"         403 "$GOT2" \
  "The rule is not constraining the method."
expect "tester POST /notify"      403 "$GOT3" \
  "The notification rule matches the namespace rather than one identity."
expect "booking POST /notify"     200 "$GOT4" \
  "403 here usually means a wrong principal string."
expect "tester GET /admin"        403 "$GOT5" \
  "200 means nothing blocked it: the request reached the application."
expect "tester GET /admin/users"  403 "$GOT6" \
  "An exact path match leaves the subtree open - use /admin* ."

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
