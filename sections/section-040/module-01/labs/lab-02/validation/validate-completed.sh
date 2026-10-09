#!/usr/bin/env bash
# Confirms the HTTPS server for the bridge is repaired: the Secret
# starfleet-credential lives in istio-ingress (where the gateway pod runs) and
# holds a certificate for starfleet.example.com signed by the lab CA, the
# Gateway serves starfleet.example.com with SIMPLE TLS from that Secret, the
# gateway proxy holds the Secret as ACTIVE, istioctl analyze no longer reports
# IST0101 for the Gateway, and - the part that matters - live HTTPS requests that
# trust only the lab CA reach the bridge.

set -u

NS="starfleet"
GW_NS="istio-ingress"
GW="starfleet-gateway"
SECRET="starfleet-credential"
HOST="starfleet.example.com"
LOCAL_PORT=18443

fail() { echo "FAIL: $*"; exit 1; }

WORK="$(mktemp -d)"
PF_PID=""
cleanup() {
  [[ -n "$PF_PID" ]] && kill "$PF_PID" >/dev/null 2>&1
  rm -rf "$WORK"
}
trap cleanup EXIT

# --- 0. the environment is still what the lab handed over -------------------
for d in bridge-v1 cargo-v1 navcom-v1 scout-v1 scout-v2 scout-v3 shuttle; do
  ready=$(kubectl -n "$NS" get deployment "$d" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [[ -n "$ready" && "$ready" -ge 1 ]] || fail "$d - deployment missing or has no ready replicas in $NS. Leave the ships alone: the faults are in the Secret and the Gateway"
done
gw_label=$(kubectl -n "$GW_NS" get deployment istio-ingress -o jsonpath='{.spec.template.metadata.labels.istio}' 2>/dev/null)
[[ "$gw_label" == "ingress" ]] || fail "the gateway Deployment istio-ingress now labels its pods istio='$gw_label'. Leave the gateway pods alone"

kubectl -n "$NS" get configmap starfleet-ca -o jsonpath='{.data.ca\.crt}' > "$WORK/ca.crt" 2>/dev/null
grep -q 'BEGIN CERTIFICATE' "$WORK/ca.crt" \
  || fail "the ConfigMap starfleet-ca in $NS has no ca.crt. Leave it in place: it is the CA clients must trust"

# --- 1. the Secret is where the gateway pod reads it -------------------------
kubectl -n "$GW_NS" get secret "$SECRET" >/dev/null 2>&1 \
  || fail "no Secret $SECRET in $GW_NS. The gateway reads TLS Secrets only from its own pod's namespace; a Secret in $NS is never delivered"
keys=$(kubectl -n "$GW_NS" get secret "$SECRET" -o go-template='{{range $k, $v := .data}}{{$k}} {{end}}' 2>/dev/null)
case " $keys " in
  *" tls.crt "*) ;;
  *) fail "Secret $SECRET in $GW_NS has keys [$keys], expected tls.crt and tls.key" ;;
esac
case " $keys " in
  *" tls.key "*) ;;
  *) fail "Secret $SECRET in $GW_NS has keys [$keys], expected tls.crt and tls.key" ;;
esac
kubectl -n "$GW_NS" get secret "$SECRET" -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d > "$WORK/tls.crt" 2>/dev/null
openssl verify -CAfile "$WORK/ca.crt" "$WORK/tls.crt" >/dev/null 2>&1 \
  || fail "the certificate in $GW_NS/$SECRET is not signed by the lab CA (ConfigMap starfleet-ca). Use the certificate and key from the Secret the lab created"
openssl x509 -in "$WORK/tls.crt" -noout -text 2>/dev/null | grep -q "DNS:$HOST" \
  || fail "the certificate in $GW_NS/$SECRET does not list $HOST in its SAN"

# --- 2. the Gateway -----------------------------------------------------------
kubectl -n "$NS" get gateway.networking.istio.io "$GW" >/dev/null 2>&1 \
  || fail "Gateway '$GW' not found in $NS - repair it, keep its name and namespace"
sel=$(kubectl -n "$NS" get gateway.networking.istio.io "$GW" -o jsonpath='{.spec.selector.istio}' 2>/dev/null)
[[ "$sel" == "ingress" ]] || fail "the Gateway selector is istio='$sel'; the gateway pods carry istio=ingress"
servers=$(kubectl -n "$NS" get gateway.networking.istio.io "$GW" \
  -o jsonpath='{range .spec.servers[*]}{.port.number}|{.port.protocol}|{.tls.mode}|{.tls.credentialName}|{.hosts}{"\n"}{end}' 2>/dev/null)
https_server=$(grep '^443|' <<<"$servers" | head -1)
[[ -n "$https_server" ]] || fail "the Gateway has no server on port 443"
IFS='|' read -r _ proto mode cred hosts <<<"$https_server"
[[ "$proto" == "HTTPS" ]] || fail "the port 443 server has protocol '$proto', expected HTTPS"
[[ "$mode" == "SIMPLE" ]] || fail "the port 443 server has tls.mode '$mode', expected SIMPLE"
[[ "$cred" == "$SECRET" ]] || fail "the port 443 server uses credentialName '$cred', expected $SECRET (a bare name, looked up in $GW_NS)"
grep -q "\"$HOST\"" <<<"$hosts" \
  || fail "the port 443 server serves hosts $hosts, not $HOST. The gateway picks the server by the SNI in the handshake, so a signal for $HOST fails with curl exit code 35"

# --- 3. the VirtualService is still linked -----------------------------------
vs_hosts=$(kubectl -n "$NS" get virtualservice bridge -o jsonpath='{.spec.hosts[*]}' 2>/dev/null)
[[ " $vs_hosts " == *" $HOST "* ]] || fail "the VirtualService bridge hosts are [$vs_hosts], expected $HOST. The flight plan was correct: leave it as it was"
gws=$(kubectl -n "$NS" get virtualservice bridge -o jsonpath='{.spec.gateways[*]}' 2>/dev/null)
case " $gws " in
  *" $GW "*|*" $NS/$GW "*) ;;
  *) fail "the VirtualService bridge gateways field is [$gws]; it must name $GW" ;;
esac

# --- 4. the gateway proxy holds the Secret as ACTIVE -------------------------
active=""
for i in $(seq 1 45); do
  if istioctl proxy-config secret deploy/istio-ingress -n "$GW_NS" 2>/dev/null \
     | grep "kubernetes://$SECRET" | grep -q ACTIVE; then
    active=1; break
  fi
  sleep 2
done
[[ -n "$active" ]] || fail "the gateway proxy does not hold kubernetes://$SECRET as ACTIVE. Check: istioctl proxy-config secret deploy/istio-ingress -n $GW_NS (WARMING means it never arrived)"

# --- 5. istioctl analyze no longer reports the missing credential -----------
if istioctl analyze -n "$NS" 2>&1 | grep -q "IST0101.*Gateway $NS/$GW"; then
  fail "istioctl analyze -n $NS still reports IST0101 for Gateway $NS/$GW: its credentialName does not resolve"
fi

# --- 6. live HTTPS requests, trusting only the lab CA ------------------------
# kubectl port-forward exits when the gateway cuts a handshake, so restart it
# whenever it is gone.
ensure_forward() {
  if [[ -n "$PF_PID" ]] && kill -0 "$PF_PID" >/dev/null 2>&1; then return 0; fi
  kubectl -n "$GW_NS" port-forward svc/istio-ingress "$LOCAL_PORT:443" >/dev/null 2>&1 &
  PF_PID=$!
  sleep 3
}

https_code() {
  ensure_forward
  curl -s -o /dev/null --max-time 10 -w '%{http_code}' --cacert "$WORK/ca.crt" \
    --resolve "$HOST:$LOCAL_PORT:127.0.0.1" "https://$HOST:$LOCAL_PORT/productpage" 2>/dev/null
  echo " $?"
}

# Gateway changes can take up to about a minute to show in live traffic:
# retry for up to about 90 s.
for i in $(seq 1 30); do
  [[ "$(https_code)" == "200 0" ]] && break
  sleep 3
done

good=0
for i in $(seq 1 5); do
  [[ "$(https_code)" == "200 0" ]] && good=$((good + 1))
done
last=$(https_code)
[[ "$good" -eq 5 ]] || fail "only $good of 5 HTTPS signals to https://$HOST/productpage got 200 with curl exit 0 (last: code and exit '$last'). Exit 35 means the gateway cut the handshake (check istioctl proxy-config secret, then the SNI and the Gateway hosts), 60 means the certificate is not trusted"

echo "PASS: $SECRET is in $GW_NS and signed by the lab CA, the Gateway serves $HOST with SIMPLE TLS from it, the gateway proxy holds it as ACTIVE, and 5 of 5 HTTPS signals that trust only the lab CA reach the bridge"
exit 0
