#!/usr/bin/env bash
# Confirms the probe's port exception now works and nothing else was opened:
#   - starfleet still has a namespace-wide STRICT policy named default
#   - the probe policy still selects app=probe, keeps the workload STRICT,
#     and keeps container port 8080 PERMISSIVE
#   - the drifter still has no sidecar, and outpost is not injected
#   - live signals: the drifter reaches the probe (200) but is still refused
#     by cargo (connection reset); the shuttle reaches both

set -u

NS="starfleet"

fail() { echo "FAIL: $*"; exit 1; }

# --- 0. the environment is still what the lab handed over -------------------
for d in cargo-v1 probe-v1 probe-v2 shuttle; do
  ready=$(kubectl -n "$NS" get deployment "$d" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [[ -n "$ready" && "$ready" -ge 1 ]] || fail "$d - deployment missing or has no ready replicas in $NS. Leave the ships alone: the fix belongs in the probe's PeerAuthentication"
done

target_port=$(kubectl -n "$NS" get service probe -o jsonpath='{.spec.ports[0].port}/{.spec.ports[0].targetPort}' 2>/dev/null)
[[ "$target_port" == "8000/8080" ]] || fail "the probe Service ports changed to '$target_port', expected 8000/8080 - leave the Service unchanged"

# --- 1. the drifter stays outside the fleet ----------------------------------
inject=$(kubectl get namespace outpost -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)
[[ "$inject" != "enabled" ]] || fail "namespace outpost is labelled istio-injection=enabled. The drifter must stay outside the mesh - remove the label and restart the drifter"

containers=$(kubectl -n outpost get pods -l app=drifter \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[*].spec.containers[*].name}' 2>/dev/null)
[[ -n "$containers" ]] || fail "no running drifter pod in outpost - do not delete it"
if grep -q istio-proxy <<<"$containers"; then
  fail "the drifter runs with an istio-proxy sidecar. It must stay outside the mesh: the task is a port exception, not a migration"
fi

# --- 2. the namespace policy is still STRICT ---------------------------------
ns_mode=$(kubectl -n "$NS" get peerauthentication default -o jsonpath='{.spec.mtls.mode}' 2>/dev/null)
ns_selector=$(kubectl -n "$NS" get peerauthentication default -o jsonpath='{.spec.selector}' 2>/dev/null)
[[ "$ns_mode" == "STRICT" && -z "$ns_selector" ]] \
  || fail "the namespace policy 'default' in $NS must stay STRICT with no selector (found mode '${ns_mode:-none}')"

# --- 3. the probe policy -------------------------------------------------------
probe_pa=$(kubectl -n "$NS" get peerauthentication -o json 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
for i in d.get("items", []):
    spec = i.get("spec", {})
    labels = spec.get("selector", {}).get("matchLabels", {})
    if labels.get("app") != "probe":
        continue
    mode = spec.get("mtls", {}).get("mode", "")
    ports = spec.get("portLevelMtls", {}) or {}
    p8080 = (ports.get("8080") or {}).get("mode", "")
    print(i["metadata"]["name"], mode or "-", p8080 or "-")
' 2>/dev/null)
[[ -n "$probe_pa" ]] || fail "no PeerAuthentication in $NS selects app=probe. The exception needs a selector"
[[ $(wc -l <<<"$probe_pa" | tr -d ' ') -eq 1 ]] || fail "more than one PeerAuthentication selects app=probe: [$probe_pa]. Keep one policy per workload"
read -r pa_name pa_mode pa_8080 <<<"$probe_pa"
[[ "$pa_mode" == "STRICT" ]] || fail "the probe policy '$pa_name' sets the workload mode to '$pa_mode'. Keep the workload STRICT and open only the port"
[[ "$pa_8080" == "PERMISSIVE" ]] || fail "the probe policy '$pa_name' does not set port 8080 to PERMISSIVE. portLevelMtls takes the container port (8080), not the Service port (8000)"

# --- 4. live signals -----------------------------------------------------------
code() {  # $1 = namespace, $2 = deployment, $3 = url
  kubectl -n "$1" exec "deploy/$2" -- curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$3" 2>/dev/null
}

drifter_probe=""
for i in $(seq 1 30); do
  drifter_probe=$(code outpost drifter http://probe.starfleet:8000/get)
  [[ "$drifter_probe" == "200" ]] && break
  sleep 2
done
[[ "$drifter_probe" == "200" ]] || fail "the drifter got '${drifter_probe:-no answer}' from probe:8000, expected 200. A 000 (connection reset) means the probe is still STRICT on its container port"

drifter_cargo=$(code outpost drifter http://cargo.starfleet:9080/details/0)
[[ "$drifter_cargo" != "200" ]] || fail "the drifter got 200 from cargo. cargo must stay STRICT - only the probe's port may accept plain signals"

shuttle_probe=$(code "$NS" shuttle http://probe:8000/get)
[[ "$shuttle_probe" == "200" ]] || fail "the shuttle got '${shuttle_probe:-no answer}' from probe, expected 200"
shuttle_cargo=$(code "$NS" shuttle http://cargo:9080/details/0)
[[ "$shuttle_cargo" == "200" ]] || fail "the shuttle got '${shuttle_cargo:-no answer}' from cargo, expected 200"

echo "PASS: starfleet stays STRICT, the probe policy keeps the workload STRICT and opens container port 8080, the drifter stays outside the mesh, reaches the probe and is still refused by cargo"
exit 0
