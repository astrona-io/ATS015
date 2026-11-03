#!/usr/bin/env bash
# Grading for ats-015-lab-020-03 - TCP authorization on tcp-echo.
# Checks that an ALLOW policy with principals and a DENY policy exist, then opens
# real TCP connections with nc:
#   shuttle -> tcp-echo:9000       reply contains "hello"
#   shuttle -> tcp-echo:9001       refused
#   shuttle -> <pod IP>:9002       refused
#   relay   -> tcp-echo:9000       refused
set -u

NS="starfleet"

fail() { echo "FAIL: $*"; exit 1; }

# Wait until no pod is starting or shutting down, so `kubectl exec deploy/x`
# never picks a pod on its way out.
settle_dataplane() {
  local i pending
  for i in $(seq 1 60); do
    pending=$(kubectl -n "$NS" get pods \
      -o jsonpath='{range .items[*]}{.metadata.deletionTimestamp}{" "}{range .status.containerStatuses[*]}{.ready}{","}{end}{"\n"}{end}' 2>/dev/null \
      | awk 'NF>1 || $0 ~ /false/')
    [ -z "$pending" ] && return 0
    sleep 2
  done
}

reply() {  # $1 = client deployment, $2 = host, $3 = port; prints the reply text
  kubectl -n "$NS" exec "deploy/$1" -c "$1" -- \
    sh -c "echo 'port $3' | nc -w 3 $2 $3" 2>/dev/null
}

# A new policy reaches new connections at once, but open connections keep the
# old rules for a while. Retry each check for up to 90 s.
expect_reply() {  # $1 = client, $2 = host, $3 = port
  local i out=""
  for i in $(seq 1 45); do
    out=$(reply "$1" "$2" "$3")
    case "$out" in *hello*) return 0 ;; esac
    sleep 2
  done
  return 1
}
expect_refused() {  # $1 = client, $2 = host, $3 = port
  local i out=""
  for i in $(seq 1 45); do
    out=$(reply "$1" "$2" "$3")
    case "$out" in *hello*) sleep 2 ;; *) return 0 ;; esac
  done
  return 1
}

for d in tcp-echo shuttle relay; do
  ready=$(kubectl -n "$NS" get deployment "$d" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ -n "$ready" ] && [ "$ready" -ge 1 ] || fail "$d - deployment missing or has no ready replicas in $NS. Do not change the Deployments"
done
mode=$(kubectl -n "$NS" get peerauthentication default -o jsonpath='{.spec.mtls.mode}' 2>/dev/null)
[ "$mode" = "STRICT" ] || fail "the PeerAuthentication 'default' in $NS is not STRICT. Leave it unchanged"

settle_dataplane

# --- 1. policies exist ------------------------------------------------------------
actions=$(kubectl -n "$NS" get authorizationpolicy -o jsonpath='{.items[*].spec.action}' 2>/dev/null)
case " $actions " in *" DENY "*) echo "OK: a DENY policy exists" ;; *) fail "no DENY policy in $NS (actions found: '${actions:-none}')" ;; esac
policies=$(kubectl -n "$NS" get authorizationpolicy -o yaml 2>/dev/null)
grep -q 'principals' <<<"$policies" || fail "no AuthorizationPolicy uses 'principals'. The ALLOW rule must name the shuttle identity"
if grep -qE '^[[:space:]]*(- )?(methods|paths|hosts):' <<<"$policies"; then
  fail "a rule uses methods, paths or hosts. These fields apply to HTTP only and do not work on TCP"
fi
echo "OK: ALLOW with principals exists, no HTTP-only field is used"

# --- 2. behaviour -----------------------------------------------------------------
expect_reply shuttle tcp-echo 9000 || fail "shuttle -> tcp-echo:9000 got no 'hello' reply. Check the ALLOW rule: principal without spiffe://, ports as strings"
echo "OK: shuttle -> tcp-echo:9000 answers"

expect_refused shuttle tcp-echo 9001 || fail "shuttle -> tcp-echo:9001 still answers. The DENY on port 9001 is missing or wrong, and DENY is checked before ALLOW"
echo "OK: shuttle -> tcp-echo:9001 is refused"

ip=$(kubectl -n "$NS" get pod -l app=tcp-echo -o jsonpath='{.items[0].status.podIP}')
[ -n "$ip" ] || fail "cannot read the tcp-echo pod IP"
expect_refused shuttle "$ip" 9002 || fail "shuttle -> pod IP:9002 still answers. An ALLOW policy that does not name 9002 must close it"
echo "OK: shuttle -> $ip:9002 is refused"

expect_refused relay tcp-echo 9000 || fail "relay -> tcp-echo:9000 still answers. The ALLOW rule must name only the shuttle identity"
echo "OK: relay -> tcp-echo:9000 is refused"

echo "PASS: only the shuttle reaches port 9000; 9001 and 9002 are closed for everyone"
exit 0
