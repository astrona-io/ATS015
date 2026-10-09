#!/usr/bin/env bash
# Confirms the gateway trusts the right CA again: the secret
# starfleet-credential-mutual in istio-ingress keeps the server certificate and
# now carries the trusted CA (example.com) as ca.crt, the Gateway and the
# VirtualService are unchanged, the gateway proxy holds the CA and demands a
# client certificate, and - the part that matters - live requests through the
# gateway: the partner gets 200, a client without a certificate and the stranger
# are refused in the handshake.

set -u

NS="starfleet"
GW_NS="istio-ingress"
GW="starfleet-gateway"
SECRET="starfleet-credential-mutual"
HOST="starfleet.example.com"
CERT_DIR="/tmp/ats-015-lab-040-02-02"
LOCAL_PORT=18443
PF_PID=""

fail() { echo "FAIL: $*"; exit 1; }
cleanup() { if [[ -n "$PF_PID" ]]; then kill "$PF_PID" >/dev/null 2>&1; wait "$PF_PID" 2>/dev/null; fi; true; }
trap cleanup EXIT

fingerprint() {  # $1 = PEM file; prints its SHA-256 fingerprint
  openssl x509 -in "$1" -noout -fingerprint -sha256 2>/dev/null | sed 's/.*=//'
}

# --- 0. the environment is still what the lab handed over -------------------
for f in example.com.crt starfleet.example.com.crt starfleet.example.com.key partner.crt partner.key stranger.crt stranger.key; do
  [[ -s "$CERT_DIR/$f" ]] || fail "$CERT_DIR/$f is missing. The grader needs the certificates the lab created; do not delete or move them"
done
for d in bridge-v1 cargo-v1 navcom-v1 scout-v1 scout-v2 scout-v3 shuttle; do
  ready=$(kubectl -n "$NS" get deployment "$d" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [[ -n "$ready" && "$ready" -ge 1 ]] || fail "$d - deployment missing or has no ready replicas in $NS. Leave the ships alone: the fix belongs in the secret"
done
gw_label=$(kubectl -n "$GW_NS" get deployment istio-ingress -o jsonpath='{.spec.template.metadata.labels.istio}' 2>/dev/null)
[[ "$gw_label" == "ingress" ]] || fail "the gateway Deployment istio-ingress in $GW_NS now labels its pods istio='$gw_label'. Leave the gateway pods alone"

# --- 1. the Gateway and the VirtualService are unchanged ---------------------
kubectl -n "$NS" get gateway.networking.istio.io "$GW" >/dev/null 2>&1 \
  || fail "Gateway '$GW' not found in $NS - it was correct, leave it in place"
servers=$(kubectl -n "$NS" get gateway.networking.istio.io "$GW" \
  -o jsonpath='{range .spec.servers[*]}{.port.number}/{.port.protocol}/{.tls.mode}/{.tls.credentialName}/{.hosts[*]};{end}' 2>/dev/null)
[[ "$servers" == "443/HTTPS/MUTUAL/$SECRET/$HOST;" ]] \
  || fail "the Gateway servers are [$servers], expected one server: 443, HTTPS, mode MUTUAL, credentialName $SECRET, host $HOST. The Gateway was correct - the fault is in the secret"

kubectl -n "$NS" get virtualservice bridge >/dev/null 2>&1 \
  || fail "VirtualService 'bridge' not found in $NS - it was correct, leave it in place"
vs=$(kubectl -n "$NS" get virtualservice bridge -o jsonpath='{.spec.hosts[*]}|{.spec.gateways[*]}|{.spec.http[0].route[0].destination.host}:{.spec.http[0].route[0].destination.port.number}' 2>/dev/null)
[[ "$vs" == "$HOST|$GW|bridge:9080" ]] || fail "the VirtualService changed (found '$vs'). It must still serve $HOST, link to $GW and route to bridge on port 9080"

# --- 2. the secret ------------------------------------------------------------
kubectl -n "$GW_NS" get secret "$SECRET" >/dev/null 2>&1 \
  || fail "secret '$SECRET' not found in $GW_NS. The gate reads credentialName from its own namespace"
keys=$(kubectl -n "$GW_NS" get secret "$SECRET" -o go-template='{{range $k, $v := .data}}{{$k}} {{end}}' 2>/dev/null)
for k in tls.crt tls.key ca.crt; do
  case " $keys " in *" $k "*) ;; *) fail "secret $SECRET has the keys [$keys], it is missing $k" ;; esac
done

tmp=$(mktemp -d)
kubectl -n "$GW_NS" get secret "$SECRET" -o jsonpath='{.data.tls\.crt}' | base64 -d > "$tmp/tls.crt" 2>/dev/null
kubectl -n "$GW_NS" get secret "$SECRET" -o jsonpath='{.data.ca\.crt}' | base64 -d > "$tmp/ca.crt" 2>/dev/null
[[ "$(fingerprint "$tmp/tls.crt")" == "$(fingerprint "$CERT_DIR/starfleet.example.com.crt")" ]] \
  || fail "tls.crt in $SECRET is not the gate's server certificate $CERT_DIR/starfleet.example.com.crt. Keep the server certificate and key; only the CA was wrong"
ca_subjects=$(openssl crl2pkcs7 -nocrl -certfile "$tmp/ca.crt" 2>/dev/null | openssl pkcs7 -print_certs -noout 2>/dev/null | grep -i '^subject')
grep -q 'other-ca' <<<"$ca_subjects" \
  && fail "ca.crt in $SECRET still contains the stranger's CA (other-ca). The gate would keep letting the stranger in"
[[ "$(fingerprint "$tmp/ca.crt")" == "$(fingerprint "$CERT_DIR/example.com.crt")" ]] \
  || fail "ca.crt in $SECRET is not the fleet's CA $CERT_DIR/example.com.crt (found: $ca_subjects)"
rm -rf "$tmp"

# --- 3. the gateway proxy holds the CA and demands a certificate ------------
ok=""
for i in $(seq 1 30); do
  if istioctl proxy-config secret deploy/istio-ingress -n "$GW_NS" 2>/dev/null \
       | grep "kubernetes://$SECRET-cacert" | grep -q ACTIVE; then
    ok=1; break
  fi
  sleep 2
done
[[ -n "$ok" ]] || fail "the gateway proxy does not hold kubernetes://$SECRET-cacert as ACTIVE. Check: istioctl proxy-config secret deploy/istio-ingress -n $GW_NS"

req=$(istioctl proxy-config listener deploy/istio-ingress -n "$GW_NS" -o json 2>/dev/null \
  | grep -c '"requireClientCertificate": true')
[[ "${req:-0}" -ge 1 ]] || fail "no gateway listener has requireClientCertificate: true. The gate is not asking for a badge"

# --- 4. live requests through the gateway ------------------------------------
kubectl -n "$GW_NS" port-forward svc/istio-ingress "$LOCAL_PORT:443" >/dev/null 2>&1 &
PF_PID=$!
sleep 4

knock() {  # $@ = extra curl args; prints the HTTP status (000 = refused in the handshake)
  curl -s -o /dev/null --max-time 10 -w '%{http_code}' --cacert "$CERT_DIR/example.com.crt" \
    --resolve "$HOST:$LOCAL_PORT:127.0.0.1" "$@" "https://$HOST:$LOCAL_PORT/productpage" 2>/dev/null
}
restart_forward() {  # a refused handshake can end the port forward; start it again
  kill "$PF_PID" >/dev/null 2>&1; wait "$PF_PID" 2>/dev/null
  kubectl -n "$GW_NS" port-forward svc/istio-ingress "$LOCAL_PORT:443" >/dev/null 2>&1 &
  PF_PID=$!
  sleep 3
}

partner=""
for i in $(seq 1 25); do   # up to ~90 s: istiod needs a moment to push a changed secret
  partner=$(knock --cert "$CERT_DIR/partner.crt" --key "$CERT_DIR/partner.key")
  [[ "$partner" == "200" ]] && break
  restart_forward
done
[[ "$partner" == "200" ]] || fail "the partner's certificate (signed by example.com) got '$partner' through the gate, expected 200. Is ca.crt the fleet's CA, and is $SECRET-cacert ACTIVE in the gateway proxy?"

nocert=""
for i in 1 2 3 4 5; do
  restart_forward
  nocert=$(knock)
  [[ "$nocert" == "000" || -z "$nocert" ]] && break
done
[[ "$nocert" == "000" || -z "$nocert" ]] || fail "a client without a certificate got '$nocert', expected to be refused in the handshake (000). The gate must stay MUTUAL"

stranger=""
for i in 1 2 3 4 5; do   # the old CA can linger a few seconds after the change
  restart_forward
  stranger=$(knock --cert "$CERT_DIR/stranger.crt" --key "$CERT_DIR/stranger.key")
  [[ "$stranger" == "000" || -z "$stranger" ]] && break
  sleep 5
done
[[ "$stranger" == "000" || -z "$stranger" ]] || fail "the stranger's certificate (signed by other-ca) got '$stranger', expected to be refused in the handshake (000). ca.crt must hold only the fleet's CA"

echo "PASS: the gate's secret keeps its server certificate and trusts only the fleet's CA, the gateway proxy holds the CA and demands a client certificate, the partner gets 200, and both a client without a certificate and the stranger are refused in the handshake"
exit 0
