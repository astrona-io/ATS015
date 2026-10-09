#!/usr/bin/env bash
# Grading for ats-015-lab-050-01 - deny a forwarded client range at the ingress gateway.
# Checks the policy (namespace, selector, remoteIpBlocks), the precondition
# (xffNumTrustedHops on the gateway listener) and live behaviour through the gateway.
set -uo pipefail
# istioctl may live in ~/.local/bin (installed by the lab bootstrap).
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

FAIL=0
PF_PIDS=()
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
cleanup() { for p in "${PF_PIDS[@]:-}"; do kill "$p" >/dev/null 2>&1 || true; done; }
trap cleanup EXIT

say "--- check 1: a policy in istio-system selects the ingress gateway ---"
# Folded in from the old config.yaml check (resourceExists authorizationpolicy -n istio-system).
if [ -z "$(kubectl -n istio-system get authorizationpolicy -o name 2>/dev/null)" ]; then
  say "FAIL: no AuthorizationPolicy exists in istio-system, the namespace of the ingress gateway."
  FAIL=1
fi
POL=$(kubectl -n istio-system get authorizationpolicy -o yaml 2>/dev/null)
if printf '%s' "$POL" | grep -q 'ingressgateway'; then
  say "OK: an AuthorizationPolicy in istio-system selects the ingress gateway."
else
  say "FAIL: no AuthorizationPolicy in istio-system selects istio: ingressgateway."
  say "      A policy in the application namespace is never delivered to the gateway pod."
  FAIL=1
fi

say "--- check 2: it matches the forwarded client address ---"
if printf '%s' "$POL" | grep -q 'remoteIpBlocks'; then
  say "OK: the rule uses remoteIpBlocks."
else
  say "FAIL: the rule does not use remoteIpBlocks."
  say "      ipBlocks matches the connection peer, which behind any proxy is the proxy."
  FAIL=1
fi

say "--- check 3: the mesh still trusts exactly one proxy hop ---"
# What matters is that the gateway ended up with xffNumTrustedHops, not that the
# string appears somewhere in meshConfig - a misplaced key is accepted and
# ignored, and remoteIpBlocks then matches nothing while everything looks set.
if istioctl proxy-config listener deploy/istio-ingressgateway -n istio-system -o json 2>/dev/null \
   | grep -q '"xffNumTrustedHops": 1'; then
  say "OK: the gateway is trusting one proxy hop (xffNumTrustedHops is set)."
else
  say "FAIL: the gateway has no xffNumTrustedHops, so it never reads the client"
  say "      address out of X-Forwarded-For and remoteIpBlocks matches nothing."
  say "      Do not reinstall Istio; this was a precondition of the lab."
  FAIL=1
fi

# kubectl port-forward exits when a connection through it fails, so each try
# starts a fresh one. A new policy takes up to about a minute to reach live
# traffic: retry for up to ~90 s before calling a result wrong.
start_pf() {
  cleanup; PF_PIDS=()
  kubectl -n istio-system port-forward svc/istio-ingressgateway 18080:80 >/dev/null 2>&1 &
  PF_PIDS+=($!)
  sleep 3
}

call() { curl -s -o /dev/null -w '%{http_code}' --max-time 15 \
  -H "Host: booking.ica.local" -H "X-Forwarded-For: $1" http://127.0.0.1:18080/book 2>/dev/null; }

GOOD=""; BAD=""
for i in $(seq 1 15); do
  start_pf
  GOOD=$(call 10.1.2.3)
  BAD=$(call 192.168.5.5)
  [ "$GOOD" = "200" ] && [ "$BAD" = "403" ] && break
  sleep 3
done

say "--- check 4: a client outside the denied range is served ---"
if [ "$GOOD" = "200" ]; then say "OK: X-Forwarded-For 10.1.2.3 -> 200"; else
  say "FAIL: X-Forwarded-For 10.1.2.3 -> '${GOOD:-no response}', expected 200."
  say "      An ALLOW policy with no narrowing closes the whole gateway; use DENY for a block-list."
  FAIL=1
fi

say "--- check 5: a client inside the denied range is refused ---"
if [ "$BAD" = "403" ]; then say "OK: X-Forwarded-For 192.168.5.5 -> 403"; else
  say "FAIL: X-Forwarded-For 192.168.5.5 -> '${BAD:-no response}', expected 403."
  say "      Check the CIDR, and that the policy really reached the gateway."
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
