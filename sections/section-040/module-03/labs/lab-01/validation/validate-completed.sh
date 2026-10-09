#!/usr/bin/env bash
# Grading for ats-015-lab-040-03 - SNI passthrough at the ingress gateway.
# Confirms the Gateway passthrough-gateway and the VirtualService passthrough
# exist in passthrough-demo (the former validation.checks), that the listener
# is TLS + PASSTHROUGH with no credential, that the route matches sniHosts,
# and - the part that matters - that a real signal through the gateway gets
# 200 with the backend's own certificate and no HTTP route for the host.
set -uo pipefail

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

say "--- check 1: the Gateway listener is PASSTHROUGH on a TLS port ---"
G=$(kubectl -n passthrough-demo get gateway passthrough-gateway -o yaml 2>/dev/null)
if [ -z "$G" ]; then
  say "FAIL: no Gateway named passthrough-gateway in passthrough-demo."; FAIL=1
else
  printf '%s' "$G" | grep -q 'PASSTHROUGH' \
    && say "OK: mode PASSTHROUGH is set." \
    || { say "FAIL: the Gateway does not use mode: PASSTHROUGH."; FAIL=1; }
  printf '%s' "$G" | grep -qE 'protocol: *TLS' \
    && say "OK: protocol TLS is set." \
    || { say "FAIL: the listener's protocol is not TLS. HTTPS would mean terminate-and-parse."; FAIL=1; }
  if printf '%s' "$G" | grep -q 'credentialName'; then
    say "FAIL: the Gateway names a credential. A passthrough listener presents nothing."
    FAIL=1
  fi
fi

say "--- check 2: the VirtualService routes on sniHosts, not on HTTP ---"
V=$(kubectl -n passthrough-demo get virtualservice passthrough -o yaml 2>/dev/null)
if [ -z "$V" ]; then
  say "FAIL: no VirtualService named passthrough in passthrough-demo."; FAIL=1
else
  printf '%s' "$V" | grep -q 'sniHosts' \
    && say "OK: a tls route matches on sniHosts." \
    || { say "FAIL: no sniHosts match. An http block cannot match an encrypted stream."; FAIL=1; }
fi

# kubectl port-forward exits after a refused or failed handshake, so restart it
# whenever it is gone.
PF_PID=""
ensure_forward() {
  if [ -n "$PF_PID" ] && kill -0 "$PF_PID" >/dev/null 2>&1; then return 0; fi
  kubectl -n istio-system port-forward svc/istio-ingressgateway 18443:443 >/dev/null 2>&1 &
  PF_PID=$!
  PF_PIDS+=("$PF_PID")
  sleep 3
}

say "--- check 3: the stream reaches the backend ---"
# Gateway changes can take up to about a minute to show in live traffic:
# retry for up to about 90 s.
CODE=""
for i in $(seq 1 30); do
  ensure_forward
  CODE=$(curl -sk --resolve secure.ica.local:18443:127.0.0.1 --max-time 10 \
    -o /dev/null -w '%{http_code}' https://secure.ica.local:18443/ 2>/dev/null)
  [ "$CODE" = "200" ] && break
  sleep 3
done
if [ "$CODE" = "200" ]; then
  say "OK: https://secure.ica.local/ -> 200"
else
  say "FAIL: https://secure.ica.local/ -> '${CODE:-connection failed}', expected 200."
  say "      A failed connection usually means an http block, or hosts/sniHosts disagreeing."
  FAIL=1
fi

ensure_forward
say "--- check 4: the certificate served belongs to the backend ---"
SUBJ=$(curl -sk -v --resolve secure.ica.local:18443:127.0.0.1 --max-time 15 \
  https://secure.ica.local:18443/ 2>&1 | grep -m1 'subject:')
case "$SUBJ" in
  *O=backend*) say "OK: served certificate is the backend's (${SUBJ#*subject: })." ;;
  *) say "FAIL: served certificate subject was '${SUBJ:-none}', expected the backend's (O=backend)."
     say "      Something terminated TLS at the gateway."
     FAIL=1 ;;
esac

say "--- check 5: the gateway has no HTTP route for this host ---"
if istioctl proxy-config routes deploy/istio-ingressgateway -n istio-system 2>/dev/null \
   | grep -q 'secure.ica.local'; then
  say "FAIL: the gateway has an HTTP route for secure.ica.local — this traffic is being terminated."
  FAIL=1
else
  say "OK: no HTTP route for secure.ica.local, as expected in passthrough."
fi

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
