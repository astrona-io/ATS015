#!/usr/bin/env bash
# Grading for ats-015-lab-050-01-02 - open one path to one network at the gate.
# Confirms the policy api-office-only lives in istio-ingress and selects the
# gateway pod, that the gateway still trusts one proxy hop (xffNumTrustedHops),
# that the Gateway and VirtualService are unchanged, and - the part that
# matters - that live signals through the gateway get the right answers:
#   /api/v1/products   from the office 203.0.113.0/24    -> 200
#   /api/v1/products   from anyone else                  -> 403 (also below it)
#   /productpage       from anyone                       -> 200
#   a forged office entry in front of the trusted one    -> 403
set -u
# istioctl may live in ~/.local/bin (installed by the lab bootstrap).
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

GW_NS="istio-ingress"
NS="starfleet"
POLICY="api-office-only"
LOCAL_PORT=18080
PF_PID=""

fail() { echo "FAIL: $*"; exit 1; }
ok() { echo "OK: $*"; }
cleanup() { [ -n "$PF_PID" ] && kill "$PF_PID" >/dev/null 2>&1; PF_PID=""; return 0; }
trap cleanup EXIT

# --- 0. the environment is still what the lab handed over -------------------
gw_sel=$(kubectl -n "$NS" get gateway.networking.istio.io starfleet-gateway -o jsonpath='{.spec.selector.istio}' 2>/dev/null)
[[ "$gw_sel" == "ingress" ]] || fail "Gateway starfleet-gateway in $NS is missing or no longer selects istio=ingress - leave the Gateway unchanged"
vs_dest=$(kubectl -n "$NS" get virtualservice starfleet -o jsonpath='{.spec.http[*].route[*].destination.host}' 2>/dev/null)
[[ "$vs_dest" == "bridge" ]] || fail "VirtualService starfleet in $NS is missing or no longer routes only to bridge (found '$vs_dest') - leave it unchanged"
ok "the Gateway and the VirtualService are unchanged"

# --- 1. the policy ------------------------------------------------------------
kubectl -n "$GW_NS" get authorizationpolicy "$POLICY" >/dev/null 2>&1 \
  || fail "AuthorizationPolicy '$POLICY' not found in $GW_NS. A gateway policy must live in the namespace where the gateway pod runs"
sel=$(kubectl -n "$GW_NS" get authorizationpolicy "$POLICY" -o jsonpath='{.spec.selector.matchLabels.istio}' 2>/dev/null)
[[ "$sel" == "ingress" ]] || fail "policy '$POLICY' selects istio='$sel'. The gateway pods carry istio=ingress (kubectl get pods -n $GW_NS -L istio)"
ok "policy $POLICY lives in $GW_NS and selects istio=ingress"

if kubectl -n "$GW_NS" get authorizationpolicy "$POLICY" -o yaml 2>/dev/null | grep -qE '(^|[^a-zA-Z])ipBlocks|notIpBlocks'; then
  fail "policy '$POLICY' uses ipBlocks/notIpBlocks. Those read the connection peer (the relay), never the client in X-Forwarded-For"
fi

# --- 2. the precondition: one trusted proxy hop --------------------------------
if istioctl proxy-config listener "deploy/istio-ingress" -n "$GW_NS" -o json 2>/dev/null | grep -q '"xffNumTrustedHops": 1'; then
  ok "the gateway trusts one proxy hop (xffNumTrustedHops: 1)"
else
  fail "the gateway listener has no xffNumTrustedHops: 1. It was set at install time - do not reinstall Istio or change numTrustedProxies"
fi

# --- 3. live signals through the gateway ------------------------------------
# kubectl port-forward exits when a connection through it fails, so each round
# starts a fresh one. A new policy takes up to about a minute to reach live
# traffic: retry every check for up to ~90 s before calling it wrong.
start_pf() {
  cleanup
  kubectl -n "$GW_NS" port-forward svc/istio-ingress "$LOCAL_PORT:80" >/dev/null 2>&1 &
  PF_PID=$!
  sleep 3
}

call() { # path, X-Forwarded-For value
  curl -s -o /dev/null -w '%{http_code}' --max-time 15 \
    -H "Host: starfleet.example.com" -H "X-Forwarded-For: $2" \
    "http://127.0.0.1:$LOCAL_PORT$1" 2>/dev/null
}

# path | X-Forwarded-For | expected code | hint
CASES='/api/v1/products|10.1.2.3|403|Clients outside 203.0.113.0/24 must be refused on the API.
/api/v1/products/0|10.1.2.3|403|Paths below /api/v1/products must be protected too.
/api/v1/products|203.0.113.7|200|The office range 203.0.113.0/24 must still reach the API.
/productpage|10.1.2.3|200|The page must stay open for everyone. An ALLOW policy refuses every signal its rules do not match - use DENY.
/productpage|192.0.2.10|200|The page must stay open for everyone.
/api/v1/products|203.0.113.7, 10.1.2.3|403|With one trusted hop the client is the LAST entry (10.1.2.3); a forged office entry in front must not help.
/api/v1/products|10.1.2.3, 203.0.113.7|200|With one trusted hop the client is the LAST entry (203.0.113.7, the office).'

run_cases() { # prints the first failing case, or nothing
  local p x want hint code
  while IFS='|' read -r p x want hint; do
    [ -z "$p" ] && continue
    code=$(call "$p" "$x")
    if [ "$code" != "$want" ]; then
      echo "$p with X-Forwarded-For '$x' -> '${code:-no response}', expected $want. $hint"
      return 0
    fi
  done <<EOF
$CASES
EOF
}

problem=""
for i in $(seq 1 15); do
  start_pf
  problem=$(run_cases)
  [ -z "$problem" ] && break
  sleep 3
done
[ -z "$problem" ] || fail "$problem"
while IFS='|' read -r p x want hint; do
  [ -n "$p" ] && ok "$p with X-Forwarded-For '$x' -> $want"
done <<EOF
$CASES
EOF

echo "RESULT: PASS"
exit 0
