#!/usr/bin/env bash
# Grading for ats-015-lab-040-01 - terminate TLS at the ingress gateway.
# Checks that the graded objects exist (Secret in istio-system, Gateway and
# VirtualService in tls-demo), that the gateway proxy really holds the
# credential, and - the part that matters - that live HTTPS with the right SNI
# answers 200 with the supplied certificate and plain HTTP answers a redirect.
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

say "--- check 1: the credential is readable by the gateway ---"
if kubectl -n istio-system get secret booking-credential >/dev/null 2>&1; then
  KEYS=$(kubectl -n istio-system get secret booking-credential \
    -o go-template='{{range $k, $v := .data}}{{$k}} {{end}}' 2>/dev/null)
  case "$KEYS" in
    *tls.crt*tls.key*|*tls.key*tls.crt*) say "OK: secret booking-credential has tls.crt and tls.key." ;;
    *) say "FAIL: secret booking-credential has keys '$KEYS', expected tls.crt and tls.key."; FAIL=1 ;;
  esac
else
  say "FAIL: no secret booking-credential in istio-system."
  say "      A credential in the application namespace is never delivered to the gateway."
  FAIL=1
fi

say "--- check 1b: the Gateway and the VirtualService exist in tls-demo ---"
if kubectl -n tls-demo get gateway.networking.istio.io booking-gateway >/dev/null 2>&1; then
  say "OK: Gateway booking-gateway exists in tls-demo."
else
  say "FAIL: no Gateway booking-gateway in tls-demo."
  FAIL=1
fi
if kubectl -n tls-demo get virtualservice booking >/dev/null 2>&1; then
  say "OK: VirtualService booking exists in tls-demo."
else
  say "FAIL: no VirtualService booking in tls-demo."
  FAIL=1
fi

say "--- check 2: the gateway proxy actually received it ---"
# A credential the gateway asked for but never received is listed as WARMING,
# so the row must say ACTIVE, not merely exist. Poll up to 90 s: the SDS push takes a moment.
HELD=""
for i in $(seq 1 45); do
  if istioctl proxy-config secret deploy/istio-ingressgateway -n istio-system 2>/dev/null \
     | grep 'booking-credential' | grep -q 'ACTIVE'; then
    HELD=1; break
  fi
  sleep 2
done
if [ -n "$HELD" ]; then
  say "OK: the gateway proxy holds booking-credential (ACTIVE)."
else
  say "FAIL: the gateway proxy does not hold booking-credential as ACTIVE."
  say "      WARMING or missing means the Secret is not where the gateway pod reads it."
  FAIL=1
fi

# kubectl port-forward exits when the gateway drops a connection (for example a
# failed handshake), so start a fresh one for every attempt.
start_forwards() {
  for p in "${PF_PIDS[@]:-}"; do kill "$p" >/dev/null 2>&1 || true; done
  PF_PIDS=()
  kubectl -n istio-system port-forward svc/istio-ingressgateway 18443:443 >/dev/null 2>&1 &
  PF_PIDS+=($!)
  kubectl -n istio-system port-forward svc/istio-ingressgateway 18080:80 >/dev/null 2>&1 &
  PF_PIDS+=($!)
  sleep 3
}

# Gateway changes take a few seconds (sometimes up to a minute) to reach the
# gateway proxy, so read live behaviour in a retry loop of up to about 90 s.
# If an earlier check already failed, one attempt is enough.
HTTPS_CODE=""; SUBJ=""; HTTP_CODE=""
ATTEMPTS=9; [ "$FAIL" -ne 0 ] && ATTEMPTS=1
for attempt in $(seq 1 "$ATTEMPTS"); do
  start_forwards
  HTTPS_CODE=$(curl -sk --resolve booking.ica.local:18443:127.0.0.1 --max-time 10 \
    -o /dev/null -w '%{http_code}' https://booking.ica.local:18443/book 2>/dev/null)
  SUBJ=$(curl -sk -v --resolve booking.ica.local:18443:127.0.0.1 --max-time 10 \
    https://booking.ica.local:18443/book 2>&1 | grep -m1 'subject:')
  HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
    -H "Host: booking.ica.local" http://127.0.0.1:18080/book 2>/dev/null)
  case "$SUBJ" in *booking.ica.local*) subj_ok=1 ;; *) subj_ok="" ;; esac
  if [ "$HTTPS_CODE" = "200" ] && [ -n "$subj_ok" ] && \
     { [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "308" ]; }; then
    break
  fi
  [ "$attempt" -lt "$ATTEMPTS" ] && sleep 7
done

say "--- check 3: HTTPS serves the booking service ---"
if [ "$HTTPS_CODE" = "200" ]; then
  say "OK: https://booking.ica.local/book -> 200"
else
  say "FAIL: https://booking.ica.local/book -> '${HTTPS_CODE:-handshake failed}', expected 200."
  say "      000 means the TLS handshake failed (credential, its namespace, or the host name)."
  say "      404 means TLS is fine and the VirtualService is not routing."
  FAIL=1
fi

say "--- check 4: the gateway serves the supplied certificate ---"
case "$SUBJ" in
  *booking.ica.local*) say "OK: served certificate subject is ${SUBJ#*subject: }" ;;
  *) say "FAIL: served certificate subject was '${SUBJ:-none}', expected CN=booking.ica.local."; FAIL=1 ;;
esac

say "--- check 5: port 80 redirects instead of serving ---"
if [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "308" ]; then
  say "OK: plain HTTP -> $HTTP_CODE"
else
  say "FAIL: plain HTTP -> '${HTTP_CODE:-no response}', expected a 301 redirect."
  say "      200 means port 80 is routing to the app instead of redirecting."
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
