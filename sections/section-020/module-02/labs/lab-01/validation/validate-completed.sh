#!/usr/bin/env bash
# Grading for ats-015-lab-020-02 - a DENY that a conflicting ALLOW cannot reopen.
# Checks that the policies exist (a DENY, and an ALLOW naming /admin), then
# sends real traffic from the tester pod and checks the sidecar's answers:
#   POST /notify      -> 200
#   GET  /admin       -> 403
#   GET  /admin/users -> 403
set -u

NS="deny-demo"

fail() { echo "FAIL: $*"; exit 1; }

# Applying the end state and grading it in the same second is a race: pods that
# are being replaced are still listed, and `kubectl exec deploy/x` will happily
# pick the one on its way out. Wait until every workload outside the system
# namespaces is settled before reading behaviour.
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

call() {  # $@ = curl args; prints the HTTP status code
  kubectl -n "$NS" exec deploy/tester -- \
    curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@" 2>/dev/null
}

# A new policy reaches new connections at once, but connections that were
# already open keep the old rules until the proxy drains them (up to about a minute).
# So retry each check for up to 90 s before calling it a failure.
expect_code() {  # $1 = expected code, rest = curl args; prints the last code seen
  local want="$1"; shift
  local i code=""
  for i in $(seq 1 45); do
    code=$(call "$@")
    [ "$code" = "$want" ] && { echo "$code"; return 0; }
    sleep 2
  done
  echo "${code:-no response}"
  return 1
}

settle_dataplane

# --- 1. at least one AuthorizationPolicy exists ------------------------------
count=$(kubectl -n "$NS" get authorizationpolicy -o name 2>/dev/null | wc -l | tr -d ' ')
[ "$count" -ge 1 ] || fail "no AuthorizationPolicy in $NS"
echo "OK: $count AuthorizationPolicy object(s) in $NS"

# --- 2. a DENY policy exists ---------------------------------------------------
actions=$(kubectl -n "$NS" get authorizationpolicy -o jsonpath='{.items[*].spec.action}' 2>/dev/null)
case " $actions " in
  *" DENY "*) echo "OK: a DENY policy exists in $NS" ;;
  *) fail "no DENY policy in $NS (actions found: '${actions:-none}')" ;;
esac

# --- 3. an ALLOW policy naming an /admin path also exists ---------------------
# One line per policy: "<action>|<paths of its rules>". A missing action means ALLOW.
allow_admin=$(kubectl -n "$NS" get authorizationpolicy \
  -o jsonpath='{range .items[*]}{.spec.action}{"|"}{.spec.rules[*].to[*].operation.paths}{"\n"}{end}' 2>/dev/null \
  | grep -E '^(ALLOW)?\|.*"/admin' || true)
[ -n "$allow_admin" ] || fail "no ALLOW policy names an /admin path. Requirement 3 asks for one, because the point of the task is that it changes nothing"
echo "OK: an ALLOW policy explicitly permits an /admin path"

# --- 4. the normal call still works -------------------------------------------
code=$(expect_code 200 -X POST http://notification-service/notify) \
  || fail "POST /notify -> $code, expected 200. Check the ALLOW for /notify, and that the DENY is not wider than /admin (for example a negative path condition)"
echo "OK: POST /notify -> 200"

# --- 5. /admin is refused despite the ALLOW -----------------------------------
code=$(expect_code 403 http://notification-service/admin) \
  || fail "GET /admin -> $code, expected 403. Any other code means the request reached the application: nothing blocked it"
echo "OK: GET /admin -> 403"

# --- 6. everything beneath /admin is refused too ------------------------------
code=$(expect_code 403 http://notification-service/admin/users) \
  || fail "GET /admin/users -> $code, expected 403. An exact path match leaves the subtree open - use /admin*"
echo "OK: GET /admin/users -> 403"

echo "PASS: /notify works, /admin and everything beneath it are refused, and the ALLOW for /admin changes nothing"
exit 0
