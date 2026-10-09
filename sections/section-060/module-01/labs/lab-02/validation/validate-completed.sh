#!/usr/bin/env bash
# Confirms that cargo and navcom are locked to the right callers with L4
# identity rules that ztunnel enforces on its own:
#   - cargo-l4 and navcom-l4 are selector-based ALLOW policies with L4 fields
#     only (no methods, paths, hosts, request principals, targetRefs)
#   - the namespace is still ambient, with no waypoint and no sidecars
#   - live requests: the shuttle's connections to cargo and navcom are closed
#     (curl 000), the bridge still reaches cargo, the scouts still get ratings
#     from navcom, and the shuttle still reaches scout (nothing over-locked)

set -u

NS="starfleet"

fail() { echo "FAIL: $*"; exit 1; }

# --- 0. the environment is still what the lab handed over -------------------
for d in bridge-v1 cargo-v1 navcom-v1 scout-v1 scout-v2 scout-v3 shuttle; do
  ready=$(kubectl -n "$NS" get deployment "$d" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [[ -n "$ready" && "$ready" -ge 1 ]] || fail "$d - deployment missing or has no ready replicas in $NS. Leave the ships alone: the task is two AuthorizationPolicy objects"
done

mode=$(kubectl get namespace "$NS" -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}' 2>/dev/null)
[[ "$mode" == "ambient" ]] || fail "namespace $NS has istio.io/dataplane-mode='$mode', expected 'ambient'. Do not change the dataplane mode"

sidecars=$(kubectl -n "$NS" get pods -o jsonpath='{range .items[*]}{.spec.containers[*].name}{" "}{.spec.initContainers[*].name}{"\n"}{end}' 2>/dev/null | grep -c 'istio-proxy')
[[ "$sidecars" -eq 0 ]] || fail "$sidecars pod(s) in $NS have an istio-proxy container. This task runs in ambient mode, with no sidecars"

waypoints=$(kubectl -n "$NS" get gateway.gateway.networking.k8s.io \
  -o jsonpath='{range .items[?(@.spec.gatewayClassName=="istio-waypoint")]}{.metadata.name}{" "}{end}' 2>/dev/null)
[[ -z "${waypoints// /}" ]] || fail "a waypoint exists in $NS ($waypoints). The task asks for L4 rules that ztunnel enforces alone - remove the waypoint"

use=$(kubectl get namespace "$NS" -o jsonpath='{.metadata.labels.istio\.io/use-waypoint}' 2>/dev/null)
[[ -z "$use" ]] || fail "namespace $NS carries istio.io/use-waypoint=$use. Remove it: no waypoint is part of this task"

# --- 1. the two policies --------------------------------------------------------
check_policy() {  # check_policy <name> <app label> <principal>
  local name="$1" app="$2" principal="$3" json sel action refs principals
  kubectl -n "$NS" get authorizationpolicy "$name" >/dev/null 2>&1 \
    || fail "AuthorizationPolicy '$name' not found in $NS"
  sel=$(kubectl -n "$NS" get authorizationpolicy "$name" -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null)
  [[ "$sel" == "$app" ]] || fail "$name selects app='$sel', expected a selector on app: $app. An L4 rule for ztunnel points at the pods with a label selector"
  refs=$(kubectl -n "$NS" get authorizationpolicy "$name" -o jsonpath='{.spec.targetRefs}{.spec.targetRef}' 2>/dev/null)
  [[ -z "$refs" ]] || fail "$name uses targetRefs. targetRefs is for a waypoint, and this task has none: use a selector"
  action=$(kubectl -n "$NS" get authorizationpolicy "$name" -o jsonpath='{.spec.action}' 2>/dev/null)
  [[ -z "$action" || "$action" == "ALLOW" ]] || fail "$name has action '$action', expected ALLOW"
  principals=$(kubectl -n "$NS" get authorizationpolicy "$name" -o jsonpath='{.spec.rules[*].from[*].source.principals[*]}' 2>/dev/null)
  [[ " $principals " == *" $principal "* ]] || fail "$name allows principals [$principals], expected $principal (no spiffe:// prefix)"
  json=$(kubectl -n "$NS" get authorizationpolicy "$name" -o json 2>/dev/null)
  if grep -qE '"(methods|notMethods|paths|notPaths|hosts|notHosts|requestPrincipals|notRequestPrincipals)"' <<<"$json" \
     || grep -qE '"key": *"request\.' <<<"$json"; then
    fail "$name contains an L7 field (method, path, host, request principal or request condition). ztunnel cannot read those and fails safe, which locks out every caller. Keep the rule to identity only"
  fi
}
check_policy cargo-l4 cargo cluster.local/ns/starfleet/sa/starfleet-bridge
check_policy navcom-l4 navcom cluster.local/ns/starfleet/sa/starfleet-scout

# --- 2. live requests -------------------------------------------------------------
status_from_shuttle() {  # status_from_shuttle <url> -> http code (000 = closed)
  kubectl -n "$NS" exec deploy/shuttle -- \
    curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$1" 2>/dev/null
}

# Policy changes take up to about a minute to reach live traffic (open
# connections keep the old rule). Retry the four requests for up to 90 s until
# they all match, then grade what the last round returned.
cargo_code=""; navcom_code=""; bridge_code=""; scout_code=""
for i in $(seq 1 30); do
  cargo_code=$(status_from_shuttle http://cargo:9080/details/0)
  navcom_code=$(status_from_shuttle http://navcom:9080/ratings/0)
  bridge_code=$(status_from_shuttle http://bridge:9080/api/v1/products/0)
  scout_code=$(status_from_shuttle http://scout:9080/reviews/0)
  [[ "$cargo_code" == "000" && "$navcom_code" == "000" && "$bridge_code" == "200" && "$scout_code" == "200" ]] && break
  sleep 3
done

[[ "$cargo_code" == "000" ]] || fail "shuttle -> cargo gave '$cargo_code', expected 000 (connection closed by ztunnel). Only starfleet-bridge may connect to cargo"
[[ "$navcom_code" == "000" ]] || fail "shuttle -> navcom gave '$navcom_code', expected 000 (connection closed by ztunnel). Only starfleet-scout may connect to navcom"
[[ "$bridge_code" == "200" ]] || fail "the bridge's product API gave '$bridge_code', expected 200. The bridge must still reach cargo - check the principal for starfleet-bridge"
[[ "$scout_code" == "200" ]] || fail "shuttle -> scout gave '$scout_code', expected 200. The task locks only cargo and navcom"

stars=0
for i in $(seq 1 12); do
  body=$(kubectl -n "$NS" exec deploy/shuttle -- curl -s --max-time 10 http://scout:9080/reviews/0 2>/dev/null)
  if grep -q 'Ratings service is currently unavailable' <<<"$body"; then
    fail "a scout answer says 'Ratings service is currently unavailable': the scouts cannot reach navcom. Check the principal for starfleet-scout"
  fi
  grep -q '"stars"' <<<"$body" && stars=$((stars + 1))
done
[[ "$stars" -ge 1 ]] || fail "12 signals to scout returned no star rating at all. The v2 and v3 scouts must still get ratings from navcom"

echo "PASS: cargo answers only starfleet-bridge and navcom only starfleet-scout, both enforced by ztunnel with no waypoint; the shuttle's connections are closed, the bridge and the scouts still get through"
exit 0
