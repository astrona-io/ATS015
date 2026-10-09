#!/usr/bin/env bash
# Grading for ats-015-lab-040-02 — MUTUAL TLS at the ingress gateway.
# Checks the secret's key names, the Gateway and VirtualService objects,
# requireClientCertificate on the gateway listener, then calls the gateway
# with and without the client certificate from /tmp.
# A successful request alone is not enough evidence, so the listener's
# requireClientCertificate is checked explicitly as well.
set -uo pipefail

FAIL=0
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
cleanup() { [ -n "${PF_PID:-}" ] && kill "$PF_PID" >/dev/null 2>&1; true; }
trap cleanup EXIT

say "--- check 1: the credential carries all three keys ---"
if kubectl -n istio-system get secret booking-credential-mtls >/dev/null 2>&1; then
  KEYS=$(kubectl -n istio-system get secret booking-credential-mtls \
    -o go-template='{{range $k, $v := .data}}{{$k}} {{end}}' 2>/dev/null)
  MISSING=""
  for k in tls.crt tls.key ca.crt; do
    case " $KEYS " in *" $k "*) ;; *) MISSING="$MISSING $k" ;; esac
  done
  if [ -z "$MISSING" ]; then
    say "OK: booking-credential-mtls has tls.crt, tls.key and ca.crt."
  else
    say "FAIL: booking-credential-mtls is missing:$MISSING (found: $KEYS)."
    say "      Without ca.crt the gateway has no CA to check client certificates against. Use kubectl create secret generic with --from-file=ca.crt=/tmp/ca.crt."
    FAIL=1
  fi
else
  say "FAIL: no secret booking-credential-mtls in istio-system."
  FAIL=1
fi

say "--- check 2: the Gateway and the VirtualService exist ---"
if kubectl -n mtlsedge-demo get gateway.networking.istio.io booking-gateway >/dev/null 2>&1; then
  MODE=$(kubectl -n mtlsedge-demo get gateway.networking.istio.io booking-gateway \
    -o jsonpath='{range .spec.servers[*]}{.port.number}:{.tls.mode}:{.tls.credentialName} {end}' 2>/dev/null)
  case " $MODE " in
    *" 443:MUTUAL:booking-credential-mtls "*) say "OK: booking-gateway has a MUTUAL server on 443 with booking-credential-mtls." ;;
    *) say "FAIL: booking-gateway servers are [$MODE], expected 443 with mode MUTUAL and credentialName booking-credential-mtls."; FAIL=1 ;;
  esac
else
  say "FAIL: no Gateway booking-gateway in mtlsedge-demo."
  FAIL=1
fi
if kubectl -n mtlsedge-demo get virtualservice booking >/dev/null 2>&1; then
  say "OK: VirtualService booking exists."
else
  say "FAIL: no VirtualService booking in mtlsedge-demo."
  FAIL=1
fi

say "--- check 3: the listener actually requires a client certificate ---"
# `--port 443` filters on the listener's own port, and the demo gateway's
# listener is 8443; read the whole dump and look at the chains themselves.
# Retry for up to ~90 s: istiod needs a moment to push a fresh Gateway.
count_required() {
  istioctl proxy-config listener deploy/istio-ingressgateway -n istio-system \
    -o json 2>/dev/null | python3 -c '
import json, sys
try:
    listeners = json.load(sys.stdin)
except Exception:
    print(0); sys.exit()
hits = 0
for l in listeners:
    for fc in l.get("filterChains", []):
        ts = fc.get("transportSocket", {}).get("typedConfig", {})
        if ts.get("requireClientCertificate"):
            hits += 1
print(hits)
'
}
REQ=0
for i in $(seq 1 30); do
  REQ=$(count_required)
  [ "${REQ:-0}" -ge 1 ] && break
  sleep 3
done
if [ "${REQ:-0}" -ge 1 ]; then
  say "OK: requireClientCertificate is true on the gateway listener."
else
  say "FAIL: requireClientCertificate is not true on the gateway's 443 listener."
  say "      The listener does not ask clients for a certificate. Check tls.mode on the Gateway."
  FAIL=1
fi

# A refused handshake can end a kubectl port-forward, so start a fresh one
# before every try.
PF_PID=""
start_forward() {
  if [ -n "$PF_PID" ]; then kill "$PF_PID" >/dev/null 2>&1; wait "$PF_PID" 2>/dev/null; fi
  kubectl -n istio-system port-forward svc/istio-ingressgateway 18443:443 >/dev/null 2>&1 &
  PF_PID=$!
  sleep 3
}
call_gateway() {  # extra curl args; prints the HTTP status (000 = refused in the handshake)
  curl -sk --resolve booking.ica.local:18443:127.0.0.1 --max-time 10 \
    -o /dev/null -w '%{http_code}' "$@" https://booking.ica.local:18443/book 2>/dev/null
}

say "--- check 4: a client with a certificate from the CA is served ---"
CODE=""
for i in $(seq 1 15); do
  start_forward
  CODE=$(call_gateway --cert /tmp/client.crt --key /tmp/client.key)
  [ "$CODE" = "200" ] && break
  sleep 3
done
if [ "$CODE" = "200" ]; then
  say "OK: client with certificate -> 200"
else
  say "FAIL: client with certificate -> '${CODE:-handshake failed}', expected 200."
  say "      404 means TLS is fine and the VirtualService is not routing."
  FAIL=1
fi

say "--- check 5: a client with no certificate is refused in the handshake ---"
CODE=""
for i in $(seq 1 5); do
  start_forward
  CODE=$(call_gateway)
  [ "$CODE" = "000" ] || [ -z "$CODE" ] && break
  sleep 3
done
if [ "$CODE" = "000" ] || [ -z "$CODE" ]; then
  say "OK: client without certificate was refused at the transport."
else
  say "FAIL: client without certificate -> '$CODE', expected a failed handshake."
  say "      The gateway is not demanding a certificate."
  FAIL=1
fi
if [ -n "$PF_PID" ]; then kill "$PF_PID" >/dev/null 2>&1; wait "$PF_PID" 2>/dev/null; PF_PID=""; fi

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
