#!/usr/bin/env bash
# Grading for LAB015-040-02 — MUTUAL TLS at the ingress gateway.
# Note: this lab fails OPEN when misconfigured, so a successful request is not
# sufficient evidence — requireClientCertificate is checked explicitly.
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
    say "      Without ca.crt there is no validation context and MUTUAL degrades to SIMPLE."
    FAIL=1
  fi
else
  say "FAIL: no secret booking-credential-mtls in istio-system."
  FAIL=1
fi

say "--- check 2: the listener actually requires a client certificate ---"
# `--port 443` filters on the listener's own port, which is not where a gateway
# TLS chain is found on 1.30; read the dump and look at the chains themselves.
REQ=$(istioctl proxy-config listener deploy/istio-ingressgateway -n istio-system \
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
')
if [ "${REQ:-0}" -ge 1 ]; then
  say "OK: requireClientCertificate is true on port 443."
else
  say "FAIL: requireClientCertificate is not true on the gateway's 443 listener."
  say "      The gateway is serving TLS and verifying nobody."
  FAIL=1
fi

kubectl -n istio-system port-forward svc/istio-ingressgateway 18443:443 >/dev/null 2>&1 &
PF_PIDS+=($!)
sleep 4

say "--- check 3: a client with a certificate from the CA is served ---"
CODE=$(curl -sk --resolve booking.ica.local:18443:127.0.0.1 --max-time 15 \
  --cert /tmp/client.crt --key /tmp/client.key \
  -o /dev/null -w '%{http_code}' https://booking.ica.local:18443/book 2>/dev/null)
if [ "$CODE" = "200" ]; then
  say "OK: client with certificate -> 200"
else
  say "FAIL: client with certificate -> '${CODE:-handshake failed}', expected 200."
  say "      404 means TLS is fine and the VirtualService is not routing."
  FAIL=1
fi

say "--- check 4: a client with no certificate is refused in the handshake ---"
CODE=$(curl -sk --resolve booking.ica.local:18443:127.0.0.1 --max-time 15 \
  -o /dev/null -w '%{http_code}' https://booking.ica.local:18443/book 2>/dev/null)
if [ "$CODE" = "000" ] || [ -z "$CODE" ]; then
  say "OK: client without certificate was refused at the transport."
else
  say "FAIL: client without certificate -> '$CODE', expected a failed handshake."
  say "      The gateway is not demanding a certificate."
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
