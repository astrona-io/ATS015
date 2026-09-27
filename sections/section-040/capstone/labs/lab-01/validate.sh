#!/usr/bin/env bash
# Grading for CAP015-040 — one gateway, terminated and passthrough side by side.
set -uo pipefail

FAIL=0
PF_PIDS=()
say() { printf '%s\n' "$*"; }
cleanup() { for p in "${PF_PIDS[@]:-}"; do kill "$p" >/dev/null 2>&1 || true; done; }
trap cleanup EXIT

say "--- check 1: a single gateway serves both hostnames ---"
G=$(kubectl -n tls-demo get gateway edge-gateway -o yaml 2>/dev/null)
if [ -z "$G" ]; then
  say "FAIL: no Gateway named edge-gateway in tls-demo."; FAIL=1
else
  printf '%s' "$G" | grep -q 'booking.ica.local' && printf '%s' "$G" | grep -q 'secure.ica.local' \
    && say "OK: edge-gateway lists both hostnames." \
    || { say "FAIL: edge-gateway does not serve both hostnames."; FAIL=1; }
  printf '%s' "$G" | grep -q 'PASSTHROUGH' \
    && say "OK: a PASSTHROUGH listener exists." \
    || { say "FAIL: no PASSTHROUGH listener."; FAIL=1; }
  printf '%s' "$G" | grep -q 'SIMPLE' \
    && say "OK: a SIMPLE (terminating) listener exists." \
    || { say "FAIL: no SIMPLE listener."; FAIL=1; }
fi

say "--- check 2: the terminating credential is where the gateway can read it ---"
kubectl -n istio-system get secret booking-credential >/dev/null 2>&1 \
  && say "OK: secret booking-credential exists in istio-system." \
  || { say "FAIL: no secret booking-credential in istio-system."; FAIL=1; }

kubectl -n istio-system port-forward svc/istio-ingressgateway 18443:443 >/dev/null 2>&1 & PF_PIDS+=($!)
kubectl -n istio-system port-forward svc/istio-ingressgateway 18080:80  >/dev/null 2>&1 & PF_PIDS+=($!)
sleep 4

say "--- check 3: the terminated hostname serves the supplied certificate ---"
OUT=$(curl -sk -v --resolve booking.ica.local:18443:127.0.0.1 --max-time 15 \
  https://booking.ica.local:18443/book 2>&1)
CODE=$(curl -sk --resolve booking.ica.local:18443:127.0.0.1 --max-time 15 \
  -o /dev/null -w '%{http_code}' https://booking.ica.local:18443/book 2>/dev/null)
SUBJ=$(printf '%s' "$OUT" | grep -m1 'subject:')
[ "$CODE" = "200" ] && say "OK: https://booking.ica.local/book -> 200" \
  || { say "FAIL: https://booking.ica.local/book -> '${CODE:-handshake failed}', expected 200."; FAIL=1; }
case "$SUBJ" in
  *booking.ica.local*) say "OK: served ${SUBJ#*subject: }" ;;
  *) say "FAIL: booking.ica.local was served '${SUBJ:-nothing}', expected CN=booking.ica.local."; FAIL=1 ;;
esac

say "--- check 4: the passthrough hostname serves the BACKEND's certificate ---"
CODE=$(curl -sk --resolve secure.ica.local:18443:127.0.0.1 --max-time 15 \
  -o /dev/null -w '%{http_code}' https://secure.ica.local:18443/ 2>/dev/null)
SUBJ=$(curl -sk -v --resolve secure.ica.local:18443:127.0.0.1 --max-time 15 \
  https://secure.ica.local:18443/ 2>&1 | grep -m1 'subject:')
[ "$CODE" = "200" ] && say "OK: https://secure.ica.local/ -> 200" \
  || { say "FAIL: https://secure.ica.local/ -> '${CODE:-connection failed}', expected 200."
       say "      An http block cannot route an encrypted stream; use a tls block on sniHosts."
       FAIL=1; }
case "$SUBJ" in
  *O=backend*) say "OK: served ${SUBJ#*subject: } — the gateway did not terminate." ;;
  *) say "FAIL: secure.ica.local was served '${SUBJ:-nothing}', expected the backend's certificate (O=backend)."
     say "      A CN=booking.ica.local certificate here means SNI matched the wrong listener."
     FAIL=1 ;;
esac

say "--- check 5: port 80 redirects ---"
CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 \
  -H "Host: booking.ica.local" http://127.0.0.1:18080/book 2>/dev/null)
if [ "$CODE" = "301" ] || [ "$CODE" = "308" ]; then say "OK: plain HTTP -> $CODE"; else
  say "FAIL: plain HTTP -> '${CODE:-no response}', expected a 301 redirect."; FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
