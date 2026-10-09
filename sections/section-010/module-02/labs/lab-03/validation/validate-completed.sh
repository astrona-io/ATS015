#!/usr/bin/env bash
# Confirms the server side was left alone (starfleet STRICT, no exception
# anywhere), the probe DestinationRule keeps its LEAST_REQUEST load balancing
# but no longer tells callers to send plain text, and - the part that matters -
# that the shuttle reaches the probe over mTLS while the drifter is refused.

set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }

# --- 0. the environment is still what the lab handed over -------------------
for d in bridge-v1 cargo-v1 navcom-v1 scout-v1 scout-v2 scout-v3 shuttle probe-v1 probe-v2; do
  ready=$(kubectl -n "$NS" get deployment "$d" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [[ -n "$ready" && "$ready" -ge 1 ]] || fail "$d - deployment missing or has no ready replicas in $NS. Leave the ships alone"
done
ready=$(kubectl -n outpost get deployment drifter -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[[ -n "$ready" && "$ready" -ge 1 ]] || fail "the drifter in outpost is missing or not ready. The grader needs it"

# --- 1. the server side is unchanged ------------------------------------------
mode=$(kubectl -n "$NS" get peerauthentication default -o jsonpath='{.spec.mtls.mode}' 2>/dev/null)
[[ "$mode" == "STRICT" ]] || fail "peerauthentication/default in $NS must stay STRICT (found '${mode:-missing}'). The server was right - fix the client side"
sel=$(kubectl -n "$NS" get peerauthentication default -o jsonpath='{.spec.selector}' 2>/dev/null)
[[ -z "$sel" ]] || fail "peerauthentication/default in $NS now has a selector. Leave it unchanged"
plm=$(kubectl -n "$NS" get peerauthentication default -o jsonpath='{.spec.portLevelMtls}' 2>/dev/null)
[[ -z "$plm" ]] || fail "peerauthentication/default in $NS now has portLevelMtls. Leave it unchanged"
all=$(kubectl get peerauthentication -A -o go-template='{{range .items}}{{.metadata.namespace}}/{{.metadata.name}} {{end}}' 2>/dev/null | tr ' ' '\n' | grep -v '^$' | grep -v "^$NS/default$")
[[ -z "$all" ]] || fail "extra PeerAuthentication found: $(echo $all). Loosening the server hides the problem - fix the DestinationRule instead"

# --- 2. the client side is fixed ------------------------------------------------
kubectl -n "$NS" get destinationrule probe >/dev/null 2>&1 \
  || fail "destinationrule/probe not found in $NS. Keep it: the team needs its LEAST_REQUEST load balancing"
lb=$(kubectl -n "$NS" get destinationrule probe -o jsonpath='{.spec.trafficPolicy.loadBalancer.simple}' 2>/dev/null)
[[ "$lb" == "LEAST_REQUEST" ]] || fail "destinationrule/probe load balancing is '${lb:-unset}', expected LEAST_REQUEST. Keep it"
tls=$(kubectl -n "$NS" get destinationrule probe -o jsonpath='{.spec.trafficPolicy.tls.mode}' 2>/dev/null)
case "$tls" in
  ""|ISTIO_MUTUAL) ;;
  *) fail "destinationrule/probe still sets tls.mode $tls. Callers must do Istio's mTLS (ISTIO_MUTUAL, or no tls block so auto mTLS decides)" ;;
esac
ptls=$(kubectl -n "$NS" get destinationrule probe -o jsonpath='{.spec.trafficPolicy.portLevelSettings[*].tls.mode}' 2>/dev/null)
grep -qE 'DISABLE|SIMPLE|MUTUAL' <<<"${ptls//ISTIO_MUTUAL/}" && fail "destinationrule/probe has a portLevelSettings tls.mode ($ptls) that is not ISTIO_MUTUAL"

# --- 3. live requests ------------------------------------------------------------
code() {  # $1 = namespace, $2 = deployment, $3 = URL; prints the HTTP code (000 = no answer)
  local c
  c=$(kubectl -n "$1" exec "deploy/$2" -- curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$3" 2>/dev/null)
  echo "${c:-000}"
}
expect() {  # $1 = wanted code, rest = code args; retries while the new configuration reaches the proxies
  local want=$1 got i; shift
  for i in $(seq 1 45); do
    got=$(code "$@")
    [[ "$got" == "$want" ]] && { echo "$got"; return 0; }
    sleep 2
  done
  echo "$got"; return 1
}

got=$(expect 200 starfleet shuttle http://probe:8000/get) \
  || fail "shuttle -> probe returned '$got', expected 200. Read the shuttle's flight log: 503 UC means the probe hung up on a plain-text signal"
echo "OK: shuttle -> probe returned 200"

headers=$(kubectl -n "$NS" exec deploy/shuttle -- curl -s --max-time 8 http://probe:8000/headers 2>/dev/null)
grep -q 'spiffe://cluster.local/ns/starfleet/sa/shuttle' <<<"$headers" \
  || fail "the probe received the shuttle's signal without the shuttle's identity (no X-Forwarded-Client-Cert). The signal must use mTLS"
echo "OK: the shuttle's identity reaches the probe"

got=$(expect 000 outpost drifter http://probe.starfleet:8000/get) \
  || fail "drifter -> probe returned '$got', expected a refused connection (000). The probe must stay STRICT"
echo "OK: the drifter is still refused"

echo "PASS: starfleet stays STRICT, the probe DestinationRule keeps LEAST_REQUEST and no longer disables TLS, and the shuttle reaches the probe over mTLS"
exit 0
