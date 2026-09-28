#!/usr/bin/env bash
# Grading for CAP015-020 — deny-by-default, two narrow doors, one DENY backstop.
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
t()  { kubectl -n "$NS" exec deploy/tester -- curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@" 2>/dev/null; }
b()  { kubectl -n "$NS" exec deploy/booking-service-v1 -c booking-service -- curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@" 2>/dev/null; }
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
if printf '%s' "$POL" | python3 -c "
import sys,yaml
d=yaml.safe_load(sys.stdin) or {}
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
  say "FAIL: no ALLOW policy names /admin. Part 3 asks for one, as the proof."
  FAIL=1
fi

say "--- check 3: the six graded calls ---"
expect "tester POST /book"        200 "$(t -X POST http://booking-service/book)" \
  "The booking ALLOW rule is missing or its selector matches no pod."
expect "tester GET /book"         403 "$(t -X GET  http://booking-service/book)" \
  "The rule is not constraining the method."
expect "tester POST /notify"      403 "$(t -X POST http://notification-service/notify)" \
  "The notification rule matches the namespace rather than one identity."
expect "booking POST /notify"     200 "$(b -X POST http://notification-service/notify)" \
  "403 here usually means a wrong principal string."
expect "tester GET /admin"        403 "$(t http://notification-service/admin)" \
  "404 means nothing blocked it: the request reached the application."
expect "tester GET /admin/users"  403 "$(t http://notification-service/admin/users)" \
  "An exact path match leaves the subtree open — use /admin* ."

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
