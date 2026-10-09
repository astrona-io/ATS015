#!/usr/bin/env bash
# Confirms the mesh stays STRICT, that one workload PeerAuthentication named
# `probe` opens the probe's CONTAINER port 8080 with portLevelMtls, and - the
# part that matters - that live signals behave: the drifter (no sidecar) reaches
# the probe but no other ship, and the shuttle still reaches the probe over mTLS.

set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }

# --- 0. the environment is still what the lab handed over -------------------
for d in bridge-v1 cargo-v1 navcom-v1 scout-v1 scout-v2 scout-v3 shuttle probe-v1 probe-v2; do
  ready=$(kubectl -n "$NS" get deployment "$d" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [[ -n "$ready" && "$ready" -ge 1 ]] || fail "$d - deployment missing or has no ready replicas in $NS. Leave the ships alone: the fix is a PeerAuthentication"
done
ready=$(kubectl -n outpost get deployment drifter -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[[ -n "$ready" && "$ready" -ge 1 ]] || fail "the drifter in outpost is missing or not ready. It is the plain-text caller the grader needs"
containers=$(kubectl -n outpost get pods -l app=drifter -o jsonpath='{.items[*].spec.containers[*].name}' 2>/dev/null)
grep -q istio-proxy <<<"$containers" && fail "the drifter now has a sidecar. Leave it outside the mesh"
target=$(kubectl -n "$NS" get service probe -o jsonpath='{.spec.ports[0].port}->{.spec.ports[0].targetPort}' 2>/dev/null)
[[ "$target" == "8000->8080" ]] || fail "the probe Service ports changed to '$target', expected 8000->8080. Leave the Service unchanged"

# --- 1. the mesh-wide policy is unchanged --------------------------------------
mesh=$(kubectl -n istio-system get peerauthentication default -o jsonpath='{.spec.mtls.mode}' 2>/dev/null)
[[ "$mesh" == "STRICT" ]] || fail "peerauthentication/default in istio-system must stay STRICT (found '${mesh:-missing}')"
others=$(kubectl -n istio-system get peerauthentication -o name 2>/dev/null | grep -v '/default$')
[[ -z "$others" ]] || fail "extra PeerAuthentication in istio-system: $others. Only the mesh-wide default belongs there"

# --- 2. no namespace-wide exception for starfleet ------------------------------
nswide=$(kubectl -n "$NS" get peerauthentication -o go-template='{{range .items}}{{if not .spec.selector}}{{.metadata.name}} {{end}}{{end}}' 2>/dev/null)
[[ -z "$nswide" ]] || fail "PeerAuthentication without a selector in $NS: $nswide. That opens the whole planet - open one port of the probe instead"

# --- 3. the probe policy -------------------------------------------------------------
kubectl -n "$NS" get peerauthentication probe >/dev/null 2>&1 \
  || fail "peerauthentication/probe not found in $NS"
app=$(kubectl -n "$NS" get peerauthentication probe -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null)
[[ "$app" == "probe" ]] || fail "peerauthentication/probe selects app='$app', expected app: probe. portLevelMtls only works in a workload policy with a selector"
mode=$(kubectl -n "$NS" get peerauthentication probe -o jsonpath='{.spec.mtls.mode}' 2>/dev/null)
case "$mode" in
  ""|UNSET|STRICT) ;;
  *) fail "peerauthentication/probe sets the whole workload to $mode. Only one port may accept plain text" ;;
esac
port_mode=$(kubectl -n "$NS" get peerauthentication probe -o go-template='{{with .spec.portLevelMtls}}{{with index . "8080"}}{{.mode}}{{end}}{{end}}' 2>/dev/null)
[[ "$port_mode" == "PERMISSIVE" ]] || fail "portLevelMtls has no PERMISSIVE entry for 8080 (found '${port_mode:-none}'). The key is the container port (8080), not the Service port (8000)"
extra=$(kubectl -n "$NS" get peerauthentication probe -o go-template='{{range $k, $v := .spec.portLevelMtls}}{{$k}} {{end}}' 2>/dev/null | tr ' ' '\n' | grep -v '^8080$' | grep -v '^$')
[[ -z "$extra" ]] || fail "portLevelMtls also lists port(s) $extra. Open exactly one port: 8080"

# --- 4. live signals -------------------------------------------------------------
code() {  # $1 = namespace, $2 = deployment, $3 = URL; prints the HTTP code (000 = no answer)
  local c
  c=$(kubectl -n "$1" exec "deploy/$2" -- curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$3" 2>/dev/null)
  echo "${c:-000}"
}
expect() {  # $1 = wanted code, rest = code args; retries while the new orders reach the proxies
  local want=$1 got i; shift
  for i in $(seq 1 45); do
    got=$(code "$@")
    [[ "$got" == "$want" ]] && { echo "$got"; return 0; }
    sleep 2
  done
  echo "$got"; return 1
}

got=$(expect 200 outpost drifter http://probe.starfleet:8000/get) \
  || fail "drifter -> probe returned '$got', expected 200. Port 8080 of the probe still refuses plain text"
echo "OK: drifter -> probe returned 200"

got=$(expect 000 outpost drifter http://scout.starfleet:9080/reviews/0) \
  || fail "drifter -> scout returned '$got', expected a refused connection (000). Only the probe may accept plain text"
got=$(expect 000 outpost drifter http://navcom.starfleet:9080/ratings/0) \
  || fail "drifter -> navcom returned '$got', expected a refused connection (000). Only the probe may accept plain text"
echo "OK: drifter is still refused by scout and navcom"

got=$(expect 200 starfleet shuttle http://probe:8000/get) \
  || fail "shuttle -> probe returned '$got', expected 200"
xfcc=$(kubectl -n "$NS" exec deploy/shuttle -- curl -s --max-time 8 http://probe:8000/headers 2>/dev/null)
grep -q 'spiffe://cluster.local/ns/starfleet/sa/shuttle' <<<"$xfcc" \
  || fail "the probe received the shuttle's signal without the shuttle's identity. The shuttle must still use mTLS - do not add a DestinationRule or set the probe to DISABLE"
echo "OK: shuttle -> probe uses mTLS"

echo "PASS: the mesh stays STRICT, peerauthentication/probe opens only container port 8080, the drifter reaches the probe and no other ship, and the shuttle still uses mTLS"
exit 0
