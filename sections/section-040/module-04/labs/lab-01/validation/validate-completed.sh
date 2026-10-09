#!/usr/bin/env bash
# Confirms TLS origination at the shuttle's sidecar for httpbin.org:
#   - the ServiceEntry charts port 80 (HTTP, targetPort 443) and port 443 (HTTPS)
#   - the DestinationRule seals ONLY port 80 with SIMPLE, sni and subjectAltNames
#   - the shuttle's proxy holds a TLS transport socket on port 80, not on 443
# and - the part that matters - that a plain http:// signal from the shuttle
# reaches httpbin.org over https on port 443, while the shuttle's own https://
# signals still work. Needs outbound internet access.

set -u

NS="starfleet"
NAME="httpbin-org"
HOST="httpbin.org"

fail() { echo "FAIL: $*"; exit 1; }

# --- 0. the environment is still what the lab handed over -------------------
ready=$(kubectl -n "$NS" get deployment shuttle -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[[ -n "$ready" && "$ready" -ge 1 ]] || fail "shuttle - deployment missing or has no ready replicas in $NS"
# Istio 1.30 injects istio-proxy as a native sidecar (an init container), so
# look in both lists.
containers=$(kubectl -n "$NS" get pods -l app=shuttle -o jsonpath='{.items[0].spec.initContainers[*].name} {.items[0].spec.containers[*].name}' 2>/dev/null)
grep -qw istio-proxy <<<"$containers" \
  || fail "the shuttle pod has no istio-proxy sidecar (containers: $containers). Run 'kubectl rollout restart deploy/shuttle -n $NS'"

# --- 1. the ServiceEntry ----------------------------------------------------
kubectl -n "$NS" get serviceentry "$NAME" >/dev/null 2>&1 \
  || fail "ServiceEntry '$NAME' not found in $NS"

hosts=$(kubectl -n "$NS" get serviceentry "$NAME" -o jsonpath='{.spec.hosts[*]}' 2>/dev/null)
grep -qw "$HOST" <<<"$hosts" || fail "the ServiceEntry hosts are [$hosts] - $HOST is missing"

se_field() { kubectl -n "$NS" get serviceentry "$NAME" -o jsonpath="$1" 2>/dev/null; }
p80=$(se_field '{.spec.ports[?(@.number==80)].protocol}')
t80=$(se_field '{.spec.ports[?(@.number==80)].targetPort}')
p443=$(se_field '{.spec.ports[?(@.number==443)].protocol}')
[[ "$p80" == "HTTP" ]] \
  || fail "port 80 is declared '$p80', expected HTTP. The sidecar can only read and seal a signal on a port it knows carries HTTP"
[[ "$t80" == "443" ]] \
  || fail "port 80 has targetPort '$t80', expected 443. Without it the sidecar sends its TLS handshake to port 80 and the call fails with WRONG_VERSION_NUMBER"
[[ "$p443" == "HTTPS" ]] \
  || fail "port 443 is declared '$p443', expected HTTPS. Keep it, so the shuttle's own https:// signals keep working"
loc=$(se_field '{.spec.location}')
res=$(se_field '{.spec.resolution}')
[[ "$loc" == "MESH_EXTERNAL" ]] || fail "location is '$loc', expected MESH_EXTERNAL"
[[ "$res" == "DNS" ]]           || fail "resolution is '$res', expected DNS"

# --- 2. the DestinationRule seals only port 80 ------------------------------
kubectl -n "$NS" get destinationrule "$NAME" >/dev/null 2>&1 \
  || fail "DestinationRule '$NAME' not found in $NS"

dr_field() { kubectl -n "$NS" get destinationrule "$NAME" -o jsonpath="$1" 2>/dev/null; }
dr_host=$(dr_field '{.spec.host}')
[[ "$dr_host" == "$HOST" ]] || fail "the DestinationRule host is '$dr_host', expected $HOST"

toptls=$(dr_field '{.spec.trafficPolicy.tls.mode}')
[[ -z "$toptls" ]] \
  || fail "the DestinationRule sets tls at the TOP level of trafficPolicy (mode '$toptls'). That seals port 443 too, so the shuttle's own https:// signals get a second seal. Put tls under portLevelSettings for port 80"

tls443=$(dr_field '{.spec.trafficPolicy.portLevelSettings[?(@.port.number==443)].tls.mode}')
[[ -z "$tls443" ]] \
  || fail "portLevelSettings for port 443 sets tls mode '$tls443'. Seal the port the app calls (80), not the server's port"

mode=$(dr_field '{.spec.trafficPolicy.portLevelSettings[?(@.port.number==80)].tls.mode}')
sni=$(dr_field '{.spec.trafficPolicy.portLevelSettings[?(@.port.number==80)].tls.sni}')
sans=$(dr_field '{.spec.trafficPolicy.portLevelSettings[?(@.port.number==80)].tls.subjectAltNames[*]}')
skip=$(dr_field '{.spec.trafficPolicy.portLevelSettings[?(@.port.number==80)].tls.insecureSkipVerify}')
[[ "$mode" == "SIMPLE" ]] || fail "the port 80 tls mode is '$mode', expected SIMPLE"
[[ "$sni" == "$HOST" ]]   || fail "the port 80 tls sni is '$sni', expected $HOST"
grep -qw "$HOST" <<<"$sans" \
  || fail "the port 80 subjectAltNames are [$sans], expected $HOST. sni only names the server; subjectAltNames makes the sidecar check the name on its certificate"
[[ "$skip" != "true" ]] \
  || fail "insecureSkipVerify is true - that switches the certificate check off. Remove it"

# --- 3. the shuttle's proxy holds a TLS socket on port 80 only --------------
ok=""
for i in $(seq 1 30); do
  c80=$(istioctl proxy-config cluster deploy/shuttle -n "$NS" --fqdn "$HOST" --port 80 -o json 2>/dev/null)
  if grep -q 'envoy.transport_sockets.tls' <<<"$c80" && grep -q "\"sni\": \"$HOST\"" <<<"$c80"; then
    ok=1; break
  fi
  sleep 2
done
[[ -n "$ok" ]] \
  || fail "the shuttle's proxy has no TLS transport socket with sni $HOST on its port 80 cluster for $HOST (istioctl proxy-config cluster deploy/shuttle -n $NS --fqdn $HOST --port 80 -o json)"
grep -q "$HOST" <<<"$(grep -A8 -i 'SubjectAltNames' <<<"$c80")" \
  || fail "the shuttle's port 80 cluster for $HOST does not check the server name $HOST - set subjectAltNames"

c443=$(istioctl proxy-config cluster deploy/shuttle -n "$NS" --fqdn "$HOST" --port 443 -o json 2>/dev/null)
[[ -n "$c443" ]] || fail "the shuttle's proxy has no port 443 cluster for $HOST - keep port 443 in the ServiceEntry"
if grep -q 'envoy.transport_sockets.tls' <<<"$c443"; then
  fail "the shuttle's port 443 cluster for $HOST also seals its connections. Only port 80 may carry the TLS transport socket"
fi

# --- 4. live signals ---------------------------------------------------------
# A plain http:// signal must arrive at httpbin.org as https.
body=""
for i in $(seq 1 30); do
  body=$(kubectl -n "$NS" exec deploy/shuttle -- curl -s --max-time 15 "http://$HOST/get" 2>/dev/null)
  grep -q "\"url\": \"https://$HOST/get\"" <<<"$body" && break
  sleep 3
done
if ! grep -q "\"url\": \"https://$HOST/get\"" <<<"$body"; then
  code=$(kubectl -n "$NS" exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}' --max-time 15 "http://$HOST/get" 2>/dev/null)
  url=$(grep -o '"url": "[^"]*"' <<<"$body")
  case "$code" in
    400) fail "http://$HOST/get answered 400: plain HTTP reached the server's TLS port. Check the DestinationRule tls block for port 80" ;;
    503) fail "http://$HOST/get answered 503. Read the shuttle's flight log: WRONG_VERSION_NUMBER means targetPort is missing, CERTIFICATE_VERIFY_FAILED means subjectAltNames does not match" ;;
    000) fail "http://$HOST/get got no answer. This lab needs outbound internet access to $HOST" ;;
    *)   fail "http://$HOST/get answered $code with ${url:-no url field}, expected \"url\": \"https://$HOST/get\" - the sidecar did not seal the signal" ;;
  esac
fi

# The shuttle's flight log must show the signal through the port 80 cluster,
# delivered to an address on port 443.
sleep 2
logline=$(kubectl -n "$NS" logs deploy/shuttle -c istio-proxy --tail=50 2>/dev/null \
  | grep '"GET /get HTTP/1.1" 200' | grep "outbound|80||$HOST" | grep ':443"' | tail -1)
[[ -n "$logline" ]] \
  || fail "the shuttle's flight log has no '\"GET /get HTTP/1.1\" 200' line through outbound|80||$HOST to an address on :443. The sidecar must read the plain signal on port 80 and deliver it to port 443"

# The shuttle's own https:// signals must still work (port 443 left alone).
code443=""
for i in $(seq 1 5); do
  code443=$(kubectl -n "$NS" exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}' --max-time 15 "https://$HOST/get" 2>/dev/null)
  [[ "$code443" == "200" ]] && break
  sleep 3
done
[[ "$code443" == "200" ]] \
  || fail "https://$HOST/get from the shuttle answered '$code443', expected 200. The shuttle's own sealed signals on port 443 must keep working"

echo "PASS: the ServiceEntry sends port 80 to 443, the DestinationRule seals only port 80 with SIMPLE, sni and subjectAltNames $HOST, the shuttle's proxy holds a TLS transport socket on port 80 only, a plain http:// signal reached $HOST as https on port 443, and the shuttle's own https:// signals still work"
exit 0
