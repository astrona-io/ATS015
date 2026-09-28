#!/usr/bin/env bash
# Grading for LAB015-020-02 — a DENY that a conflicting ALLOW cannot reopen.
set -uo pipefail

NS="deny-demo"
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
call() { kubectl -n "$NS" exec deploy/tester -- \
  curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@" 2>/dev/null; }

say "--- check 1: a DENY policy exists on notification-service ---"
ACTIONS=$(kubectl -n "$NS" get authorizationpolicy -o jsonpath='{.items[*].spec.action}' 2>/dev/null)
case "$ACTIONS" in
  *DENY*) say "OK: a DENY policy exists in $NS." ;;
  *) say "FAIL: no DENY policy in $NS (actions found: '${ACTIONS:-none}')."; FAIL=1 ;;
esac

say "--- check 2: an ALLOW policy naming /admin also exists ---"
if kubectl -n "$NS" get authorizationpolicy -o yaml 2>/dev/null \
   | python3 -c "
import sys,yaml
d=yaml.safe_load(sys.stdin) or {}
hit=False
for i in d.get('items',[]):
    if i['spec'].get('action','ALLOW')!='ALLOW': continue
    for r in i['spec'].get('rules') or []:
        for t in r.get('to') or []:
            for p in (t.get('operation',{}).get('paths') or []):
                if p.startswith('/admin'): hit=True
sys.exit(0 if hit else 1)"; then
  say "OK: an ALLOW policy explicitly permits an /admin path."
else
  say "FAIL: no ALLOW policy names an /admin path. Requirement 3 asks for one,"
  say "      because the point of the task is that it changes nothing."
  FAIL=1
fi

say "--- check 3: the normal call still works ---"
CODE=$(call -X POST http://notification-service/notify)
if [ "$CODE" = "200" ]; then say "OK: POST /notify -> 200"; else
  say "FAIL: POST /notify -> '${CODE:-no response}', expected 200."
  say "      The DENY is probably wider than /admin — check for a negated path condition."
  FAIL=1
fi

say "--- check 4: /admin is refused despite the ALLOW ---"
CODE=$(call http://notification-service/admin)
if [ "$CODE" = "403" ]; then say "OK: GET /admin -> 403"; else
  say "FAIL: GET /admin -> '${CODE:-no response}', expected 403."
  say "      404 means the request reached the application: nothing blocked it."
  FAIL=1
fi

say "--- check 5: everything beneath /admin is refused too ---"
CODE=$(call http://notification-service/admin/users)
if [ "$CODE" = "403" ]; then say "OK: GET /admin/users -> 403"; else
  say "FAIL: GET /admin/users -> '${CODE:-no response}', expected 403."
  say "      An exact path match leaves the subtree open — use /admin* ."
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
