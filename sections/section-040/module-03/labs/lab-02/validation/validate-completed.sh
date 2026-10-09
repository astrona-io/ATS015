#!/usr/bin/env bash
# Confirms the passthrough setup of tls-backend in starfleet is repaired: the Gateway
# vault-gateway has a TLS PASSTHROUGH server on 443 for
# vault.starfleet.example.com with no credential, the VirtualService
# tls-backend routes with a tls block on sniHosts (no http block) to
# tls-backend:8443, and - the part that matters - a real request through the
# gateway with that SNI name gets 200 with tls-backend's own certificate, while
# the gateway holds no HTTP route for the host.

set -u

NS="starfleet"
HOST="vault.starfleet.example.com"
GW="vault-gateway"
VS="tls-backend"
LOCAL_PORT=18443
PF_PID=""

cleanup() { [[ -n "$PF_PID" ]] && kill "$PF_PID" 2>/dev/null; }
fail() { cleanup; echo "FAIL: $*"; exit 1; }
trap cleanup EXIT

# --- 0. the environment is still what the lab handed over -------------------
ready=$(kubectl -n "$NS" get deployment tls-backend -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[[ -n "$ready" && "$ready" -ge 1 ]] || fail "deployment tls-backend is missing or not ready in $NS. Leave the vault alone: the faults are in the Gateway and the VirtualService"
svc_port=$(kubectl -n "$NS" get service tls-backend -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
[[ "$svc_port" == "8443" ]] || fail "Service tls-backend port is '$svc_port', expected 8443. Do not change the vault"
gwr=$(kubectl -n istio-ingress get deployment istio-ingress -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[[ -n "$gwr" && "$gwr" -ge 1 ]] || fail "the ingress gateway istio-ingress is not ready in istio-ingress"

# --- 1. the Gateway ----------------------------------------------------------
kubectl -n "$NS" get gateways.networking.istio.io "$GW" >/dev/null 2>&1 \
  || fail "Gateway '$GW' not found in $NS"
sel=$(kubectl -n "$NS" get gateways.networking.istio.io "$GW" -o jsonpath='{.spec.selector.istio}' 2>/dev/null)
[[ "$sel" == "ingress" ]] || fail "the Gateway selector is istio='$sel', expected 'ingress' (the label on the gateway pods)"

server=$(kubectl -n "$NS" get gateways.networking.istio.io "$GW" \
  -o jsonpath='{range .spec.servers[*]}{.port.number}|{.port.protocol}|{.tls.mode}|{.tls.credentialName}|{.hosts[*]}{"\n"}{end}' 2>/dev/null \
  | grep -E "(^|[ |])$HOST( |$)" | head -1)
[[ -n "$server" ]] || fail "no server on '$GW' lists the host $HOST. Check the Gateway's hosts for a typo: they must match the SNI name the visitor sends"
IFS='|' read -r s_port s_proto s_mode s_cred _ <<<"$server"
[[ "$s_port" == "443" ]] || fail "the server for $HOST is on port '$s_port', expected 443"
[[ "$s_proto" == "TLS" ]] || fail "the server for $HOST uses protocol '$s_proto', expected TLS. HTTPS would mean the gateway ends TLS"
[[ "$s_mode" == "PASSTHROUGH" ]] || fail "the server for $HOST uses tls.mode '$s_mode', expected PASSTHROUGH"
[[ -z "$s_cred" ]] || fail "the server for $HOST names credentialName '$s_cred'. A passthrough server shows no certificate of its own"

# --- 2. the VirtualService ---------------------------------------------------
kubectl -n "$NS" get virtualservice "$VS" >/dev/null 2>&1 \
  || fail "VirtualService '$VS' not found in $NS"
vs_http=$(kubectl -n "$NS" get virtualservice "$VS" -o jsonpath='{.spec.http}' 2>/dev/null)
[[ -z "$vs_http" ]] || fail "the VirtualService still has an http block. The gateway cannot read HTTP in a sealed stream; use a tls block"
vs_gws=$(kubectl -n "$NS" get virtualservice "$VS" -o jsonpath='{.spec.gateways[*]}' 2>/dev/null)
grep -qE "(^| )($NS/)?$GW( |$)" <<<"$vs_gws" || fail "the VirtualService is bound to [$vs_gws], expected $GW"
sni=$(kubectl -n "$NS" get virtualservice "$VS" -o jsonpath='{.spec.tls[*].match[*].sniHosts[*]}' 2>/dev/null)
grep -qw "$HOST" <<<"$sni" || fail "the VirtualService tls rule matches sniHosts [$sni], expected $HOST"
dest=$(kubectl -n "$NS" get virtualservice "$VS" -o jsonpath='{.spec.tls[0].route[0].destination.host}:{.spec.tls[0].route[0].destination.port.number}' 2>/dev/null)
case "$dest" in
  tls-backend:8443|tls-backend.starfleet:8443|tls-backend.starfleet.svc.cluster.local:8443) ;;
  *) fail "the tls rule sends to '$dest', expected tls-backend on port 8443 (the port where the vault ends TLS itself)" ;;
esac

# --- 3. live requests through the gateway ------------------------------------
# kubectl port-forward exits after a refused or failed handshake, so restart it
# whenever it is gone.
ensure_forward() {
  if [[ -n "$PF_PID" ]] && kill -0 "$PF_PID" >/dev/null 2>&1; then return 0; fi
  kubectl -n istio-ingress port-forward svc/istio-ingress "$LOCAL_PORT:443" >/dev/null 2>&1 &
  PF_PID=$!
  sleep 3
}

# Gateway changes can take up to about a minute to show in live traffic:
# retry for up to about 90 s.
code=""
for i in $(seq 1 30); do
  ensure_forward
  code=$(curl -sk --max-time 10 --resolve "$HOST:$LOCAL_PORT:127.0.0.1" \
    -o /dev/null -w '%{http_code}' "https://$HOST:$LOCAL_PORT/" 2>/dev/null)
  [[ "$code" == "200" ]] && break
  sleep 3
done
[[ "$code" == "200" ]] || fail "a signal to https://$HOST/ through the gateway got '${code:-no answer}', expected 200. A failed connection (000) means the stream has nowhere to go: an http block, or hosts and sniHosts that disagree"

ensure_forward
body=$(curl -sk --max-time 10 --resolve "$HOST:$LOCAL_PORT:127.0.0.1" "https://$HOST:$LOCAL_PORT/" 2>/dev/null)
grep -q "vault ended TLS itself" <<<"$body" || fail "the reply was '$body', expected the vault's own reply"

subject=$(curl -sk -v --max-time 10 --resolve "$HOST:$LOCAL_PORT:127.0.0.1" "https://$HOST:$LOCAL_PORT/" 2>&1 | grep -m1 'subject:')
grep -qE 'O ?= ?vault' <<<"$subject" || fail "the certificate served was '${subject:-none}', expected the vault's own (O=vault). Something ended TLS at the gateway"

# --- 4. no HTTP route for the host on the gateway -----------------------------
if istioctl proxy-config routes deploy/istio-ingress -n istio-ingress 2>/dev/null | grep -q "$HOST"; then
  fail "the gateway holds an HTTP route for $HOST, so it is reading this traffic. A passthrough host has none"
fi

echo "PASS: vault-gateway passes $HOST through on 443 with no credential, the tls-backend VirtualService routes on sniHosts to tls-backend:8443, the signal gets 200 with the vault's own certificate, and the gateway holds no HTTP route for the host"
exit 0
