#!/usr/bin/env bash
# Confirms the Starfleet's least-privilege guest lists work again:
#   - the fleet, the shuttle and the STRICT PeerAuthentication are unchanged
#   - allow-nothing is still the empty guest list for the whole planet
#   - scout-allow-bridge and navcom-allow-scout select their own ships and
#     name exactly the right caller (no namespace-wide or empty rules)
#   - navcom's proxy really holds navcom-allow-scout
#   - live signals: the bridge page shows reviews and star ratings with no
#     "currently unavailable" error, and every shortcut from the shuttle to
#     cargo, scout and navcom is refused with 403

set -u

# Use the pinned istioctl the bootstrap installed, before any other on the PATH.
export PATH="/usr/local/bin:$HOME/.local/bin:$PATH"

NS="starfleet"
BRIDGE_SA="cluster.local/ns/starfleet/sa/starfleet-bridge"
SCOUT_SA="cluster.local/ns/starfleet/sa/starfleet-scout"

fail() { echo "FAIL: $*"; exit 1; }

# --- 0. the environment is still what the lab handed over -------------------
for d in bridge-v1 cargo-v1 navcom-v1 scout-v1 scout-v2 scout-v3 shuttle; do
  ready=$(kubectl -n "$NS" get deployment "$d" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [[ -n "$ready" && "$ready" -ge 1 ]] || fail "$d - deployment missing or has no ready replicas in $NS. Leave the ships alone: the fix belongs in the AuthorizationPolicies"
done

deploy_count=$(kubectl -n "$NS" get deployments -o name 2>/dev/null | wc -l | tr -d ' ')
[[ "$deploy_count" -eq 7 ]] || fail "$NS holds $deploy_count deployments, expected exactly 7 - do not add or remove ships"

for pair in bridge-v1:starfleet-bridge cargo-v1:starfleet-cargo navcom-v1:starfleet-navcom scout-v1:starfleet-scout scout-v2:starfleet-scout scout-v3:starfleet-scout shuttle:shuttle; do
  d="${pair%%:*}"; want="${pair##*:}"
  sa=$(kubectl -n "$NS" get deployment "$d" -o jsonpath='{.spec.template.spec.serviceAccountName}' 2>/dev/null)
  [[ "$sa" == "$want" ]] || fail "deployment $d now runs as service account '$sa', expected '$want'. Do not change the ships' registration papers - fix the policy instead"
done

pa_mode=$(kubectl -n "$NS" get peerauthentication default -o jsonpath='{.spec.mtls.mode}' 2>/dev/null)
[[ "$pa_mode" == "STRICT" ]] || fail "PeerAuthentication 'default' in $NS has mode '$pa_mode', expected STRICT - leave it in place"

# --- 1. allow-nothing is still the empty guest list --------------------------
kubectl -n "$NS" get authorizationpolicy allow-nothing >/dev/null 2>&1 \
  || fail "AuthorizationPolicy 'allow-nothing' not found in $NS - the planet must stay deny-by-default"
an_spec=$(kubectl -n "$NS" get authorizationpolicy allow-nothing -o jsonpath='{.spec}' 2>/dev/null)
an_action=$(kubectl -n "$NS" get authorizationpolicy allow-nothing -o jsonpath='{.spec.action}' 2>/dev/null)
an_selector=$(kubectl -n "$NS" get authorizationpolicy allow-nothing -o jsonpath='{.spec.selector}' 2>/dev/null)
an_rules=$(kubectl -n "$NS" get authorizationpolicy allow-nothing -o jsonpath='{.spec.rules}' 2>/dev/null)
if [[ -n "$an_selector" || -n "$an_rules" || ( -n "$an_action" && "$an_action" != "ALLOW" ) ]]; then
  fail "allow-nothing is no longer empty (spec: $an_spec). It must stay 'spec: {}': no selector, no rules"
fi

# No policy on the planet may open everything with an empty rule.
if kubectl -n "$NS" get authorizationpolicy \
     -o jsonpath='{range .items[*]}{.metadata.name}={.spec.rules}{"\n"}{end}' 2>/dev/null \
     | grep -qE '(\[|,)\{\}(,|\])'; then
  fail "a policy in $NS has 'rules: [{}]', which allows every signal. Fix the two broken lists instead of opening the planet"
fi

# --- 2. the two repaired lists -------------------------------------------------
check_list() {  # $1 policy name, $2 app label, $3 the one allowed principal
  local name="$1" app="$2" principal="$3" sel principals namespaces
  kubectl -n "$NS" get authorizationpolicy "$name" >/dev/null 2>&1 \
    || fail "AuthorizationPolicy '$name' not found in $NS - repair it, do not delete it"
  sel=$(kubectl -n "$NS" get authorizationpolicy "$name" -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null)
  [[ "$sel" == "$app" ]] || fail "$name selects app='$sel', expected app='$app'. A selector that matches no pod never reaches the ship"
  principals=$(kubectl -n "$NS" get authorizationpolicy "$name" -o jsonpath='{.spec.rules[*].from[*].source.principals[*]}' 2>/dev/null)
  [[ "$principals" == "$principal" ]] || fail "$name allows principals [$principals], expected exactly $principal. Read the caller's service account from its pod"
  namespaces=$(kubectl -n "$NS" get authorizationpolicy "$name" -o jsonpath='{.spec.rules[*].from[*].source.namespaces[*]}' 2>/dev/null)
  [[ -z "$namespaces" ]] || fail "$name allows whole namespaces [$namespaces]. Least privilege names one caller by its service account"
}
check_list scout-allow-bridge scout "$BRIDGE_SA"
check_list navcom-allow-scout navcom "$SCOUT_SA"

# --- 3. navcom's proxy really holds its list ---------------------------------
ok=""
for i in $(seq 1 30); do
  if istioctl proxy-config listener deploy/navcom-v1 -n "$NS" --port 15006 -o json 2>/dev/null \
       | grep -q 'policy\[navcom-allow-scout\]'; then
    ok=1; break
  fi
  sleep 2
done
[[ -n "$ok" ]] || fail "navcom's proxy does not hold navcom-allow-scout (istioctl proxy-config listener deploy/navcom-v1 -n $NS --port 15006 -o json). Check the policy's selector against navcom's pod labels"

# --- 4. live signals -----------------------------------------------------------
page() {  # one load of the bridge page from the shuttle
  kubectl -n "$NS" exec deploy/shuttle -- curl -s --max-time 10 http://bridge:9080/productpage 2>/dev/null
}

# Connections opened before the fix can keep the old rules for up to about
# a minute. Wait until the page loads cleanly with stars, then judge.
settled=""
for i in $(seq 1 45); do
  body=$(page)
  if grep -q 'glyphicon-star' <<<"$body" && ! grep -q 'currently unavailable' <<<"$body"; then
    settled=1; break
  fi
  sleep 2
done
[[ -n "$settled" ]] || fail "the bridge page never showed star ratings without an error. 'product reviews are currently unavailable' means the scouts refuse the bridge; 'Ratings service is currently unavailable' means navcom refuses the scouts"

errors=0; stars=0
for i in $(seq 1 12); do
  body=$(page)
  grep -q 'currently unavailable' <<<"$body" && errors=$((errors + 1))
  grep -q 'glyphicon-star' <<<"$body" && stars=$((stars + 1))
done
[[ "$errors" -eq 0 ]] || fail "$errors of 12 bridge page loads still show 'currently unavailable'. Some call on the map is still refused"
[[ "$stars" -ge 1 ]] || fail "none of 12 bridge page loads showed star ratings. The v2 and v3 scouts cannot reach navcom"

code() {  # status code of one signal from the shuttle
  kubectl -n "$NS" exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$1" 2>/dev/null
}
bridge_code=$(code http://bridge:9080/productpage)
[[ "$bridge_code" == "200" ]] || fail "shuttle -> bridge /productpage gave '$bridge_code', expected 200. The bridge is the front page: any caller may GET it"
for target in http://cargo:9080/details/0 http://scout:9080/reviews/0 http://navcom:9080/ratings/0; do
  got=$(code "$target")
  [[ "$got" == "403" ]] || fail "shuttle -> $target gave '$got', expected 403. Only the ship on the call map may call it, so the shuttle must be refused"
done

echo "PASS: allow-nothing still closes the planet, scout-allow-bridge names starfleet-bridge, navcom-allow-scout selects navcom and reaches its proxy, the bridge page shows reviews and stars with no errors, and every shortcut from the shuttle gets 403"
exit 0
