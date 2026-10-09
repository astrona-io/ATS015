#!/usr/bin/env bash
# Grading for ats-015-lab-020-02-02 - make the probe read-only with one DENY.
# Confirms the starting ALLOW policy probe-allow-fleet is unchanged, that
# probe-read-only is a DENY on the probe built on notMethods, and - the part
# that matters - that live requests get the right answers:
#   shuttle GET /get -> 200      fortio GET /get       -> 200
#   shuttle POST /post -> 403    fortio POST /post     -> 403
#   shuttle DELETE /delete -> 403, shuttle PATCH /anything -> 403
set -u

NS="starfleet"
PROBE="http://probe:8000"

fail() { echo "FAIL: $*"; exit 1; }

# --- 0. the environment is still what the lab handed over -------------------
for d in probe-v1 probe-v2 shuttle fortio; do
  ready=$(kubectl -n "$NS" get deployment "$d" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [[ -n "$ready" && "$ready" -ge 1 ]] || fail "$d - deployment missing or has no ready replicas in $NS. Leave the ships alone"
done

mode=$(kubectl -n "$NS" get peerauthentication default -o jsonpath='{.spec.mtls.mode}' 2>/dev/null)
[[ "$mode" == "STRICT" ]] || fail "PeerAuthentication default in $NS has mode '$mode', expected STRICT - leave it unchanged"

# --- 1. the starting ALLOW policy is unchanged -------------------------------
kubectl -n "$NS" get authorizationpolicy probe-allow-fleet >/dev/null 2>&1 \
  || fail "AuthorizationPolicy probe-allow-fleet is gone. The task says to leave it in place"
allow_action=$(kubectl -n "$NS" get authorizationpolicy probe-allow-fleet -o jsonpath='{.spec.action}' 2>/dev/null)
[[ -z "$allow_action" || "$allow_action" == "ALLOW" ]] || fail "probe-allow-fleet now has action '$allow_action' - leave it unchanged"
allow_app=$(kubectl -n "$NS" get authorizationpolicy probe-allow-fleet -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null)
allow_ns=$(kubectl -n "$NS" get authorizationpolicy probe-allow-fleet -o jsonpath='{.spec.rules[*].from[*].source.namespaces[*]}' 2>/dev/null)
allow_to=$(kubectl -n "$NS" get authorizationpolicy probe-allow-fleet -o jsonpath='{.spec.rules[*].to}' 2>/dev/null)
[[ "$allow_app" == "probe" && "$allow_ns" == "starfleet" && -z "$allow_to" ]] \
  || fail "probe-allow-fleet was changed (selector app='$allow_app', namespaces='$allow_ns', to='$allow_to'). Make the probe read-only with a DENY, not by editing the guest list"
echo "OK: probe-allow-fleet is unchanged"

# --- 2. probe-read-only is a DENY on the probe built on notMethods -----------
kubectl -n "$NS" get authorizationpolicy probe-read-only >/dev/null 2>&1 \
  || fail "AuthorizationPolicy probe-read-only not found in $NS"
deny_action=$(kubectl -n "$NS" get authorizationpolicy probe-read-only -o jsonpath='{.spec.action}' 2>/dev/null)
[[ "$deny_action" == "DENY" ]] || fail "probe-read-only has action '${deny_action:-ALLOW (default)}', expected DENY"
deny_app=$(kubectl -n "$NS" get authorizationpolicy probe-read-only -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null)
[[ "$deny_app" == "probe" ]] || fail "probe-read-only selects app='$deny_app', expected app: probe (only the probe becomes read-only)"
not_methods=$(kubectl -n "$NS" get authorizationpolicy probe-read-only -o jsonpath='{.spec.rules[*].to[*].operation.notMethods}' 2>/dev/null)
grep -q '"GET"' <<<"$not_methods" \
  || fail "probe-read-only does not use notMethods with GET (found '$not_methods'). One negative field covers every method except GET, including ones you did not think of"
echo "OK: probe-read-only is a DENY on the probe with notMethods [GET]"

# --- 3. live requests --------------------------------------------------------
from_shuttle() {  # $@ = curl args; prints the HTTP status code
  kubectl -n "$NS" exec deploy/shuttle -- \
    curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@" 2>/dev/null
}
from_fortio() {  # $@ = fortio load args; prints the HTTP status code
  # fortio load prints "Code 200 : 1 (100.0 %)"; keep only the number.
  kubectl -n "$NS" exec deploy/fortio -c fortio -- \
    fortio load -quiet -n 1 "$@" 2>&1 | grep -o 'Code [0-9]*' | head -1 | awk '{print $2}'
}

# A new policy reaches new connections at once, but connections that were
# already open keep the old rules until the proxy drains them (up to about a minute).
# So retry each check for up to 90 s before calling it a failure.
expect_code() {  # $1 = expected code, $2 = caller function, rest = args
  local want="$1" caller="$2"; shift 2
  local i code=""
  for i in $(seq 1 45); do
    code=$("$caller" "$@")
    [[ "$code" == "$want" ]] && { echo "$code"; return 0; }
    sleep 2
  done
  echo "${code:-no response}"
  return 1
}

code=$(expect_code 200 from_shuttle "$PROBE/get") \
  || fail "shuttle GET /get -> $code, expected 200. Reads must still work - is the DENY wider than every method except GET?"
echo "OK: shuttle GET /get -> 200"

code=$(expect_code 200 from_fortio "$PROBE/get") \
  || fail "fortio GET /get -> $code, expected 200. Reads must work for every starfleet caller"
echo "OK: fortio GET /get -> 200"

code=$(expect_code 403 from_shuttle -X POST "$PROBE/post") \
  || fail "shuttle POST /post -> $code, expected 403. probe-allow-fleet lets it in unless a DENY fits first"
echo "OK: shuttle POST /post -> 403"

code=$(expect_code 403 from_fortio -X POST "$PROBE/post") \
  || fail "fortio POST /post -> $code, expected 403. The ban must cover every caller - does the DENY have a 'from' part?"
echo "OK: fortio POST /post -> 403"

code=$(expect_code 403 from_shuttle -X DELETE "$PROBE/delete") \
  || fail "shuttle DELETE /delete -> $code, expected 403"
echo "OK: shuttle DELETE /delete -> 403"

code=$(expect_code 403 from_shuttle -X PATCH "$PROBE/anything") \
  || fail "shuttle PATCH /anything -> $code, expected 403. A list of banned methods misses the ones you did not name; ban everything that is not GET"
echo "OK: shuttle PATCH /anything -> 403"

echo "PASS: the probe answers GET from every caller and refuses every other method, while probe-allow-fleet stays in place"
exit 0
