#!/usr/bin/env bash
# Grading for LAB015-040-01 — terminate TLS at the ingress gateway.
set -uo pipefail

FAIL=0
PF_PIDS=()
say() { printf '%s\n' "$*"; }
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

say "--- check 2: the gateway proxy actually received it ---"
if istioctl proxy-config secret deploy/istio-ingressgateway -n istio-system 2>/dev/null \
   | grep -q 'booking-credential'; then
  say "OK: the gateway proxy holds booking-credential."
else
  say "FAIL: the gateway proxy does not hold booking-credential."
  FAIL=1
fi

kubectl -n istio-system port-forward svc/istio-ingressgateway 18443:443 >/dev/null 2>&1 &
PF_PIDS+=($!)
kubectl -n istio-system port-forward svc/istio-ingressgateway 18080:80 >/dev/null 2>&1 &
PF_PIDS+=($!)
sleep 4

say "--- check 3: HTTPS serves the booking service ---"
CODE=$(curl -sk --resolve booking.ica.local:18443:127.0.0.1 --max-time 15 \
  -o /dev/null -w '%{http_code}' https://booking.ica.local:18443/book 2>/dev/null)
if [ "$CODE" = "200" ]; then
  say "OK: https://booking.ica.local/book -> 200"
else
  say "FAIL: https://booking.ica.local/book -> '${CODE:-handshake failed}', expected 200."
  say "      000 means the TLS listener never came up (credential or port name)."
  say "      404 means TLS is fine and the VirtualService is not routing."
  FAIL=1
fi

say "--- check 4: the gateway serves the supplied certificate ---"
SUBJ=$(curl -sk -v --resolve booking.ica.local:18443:127.0.0.1 --max-time 15 \
  https://booking.ica.local:18443/book 2>&1 | grep -m1 'subject:')
case "$SUBJ" in
  *booking.ica.local*) say "OK: served certificate subject is ${SUBJ#*subject: }" ;;
  *) say "FAIL: served certificate subject was '${SUBJ:-none}', expected CN=booking.ica.local."; FAIL=1 ;;
esac

say "--- check 5: port 80 redirects instead of serving ---"
CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 \
  -H "Host: booking.ica.local" http://127.0.0.1:18080/book 2>/dev/null)
if [ "$CODE" = "301" ] || [ "$CODE" = "308" ]; then
  say "OK: plain HTTP -> $CODE"
else
  say "FAIL: plain HTTP -> '${CODE:-no response}', expected a 301 redirect."
  say "      200 means port 80 is routing to the app instead of redirecting."
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
