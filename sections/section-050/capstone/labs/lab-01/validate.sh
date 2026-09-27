#!/usr/bin/env bash
# Grading for CAP015-050 — a global block-list plus a path-scoped allow-list.
set -uo pipefail

FAIL=0
PF_PIDS=()
say() { printf '%s\n' "$*"; }
cleanup() { for p in "${PF_PIDS[@]:-}"; do kill "$p" >/dev/null 2>&1 || true; done; }
trap cleanup EXIT

say "--- check 1: gateway-scoped policies using the forwarded client address ---"
POL=$(kubectl -n istio-system get authorizationpolicy -o yaml 2>/dev/null)
printf '%s' "$POL" | grep -q 'ingressgateway' \
  && say "OK: a policy in istio-system selects the ingress gateway." \
  || { say "FAIL: no policy in istio-system selects istio: ingressgateway."; FAIL=1; }
printf '%s' "$POL" | grep -q 'emoteIpBlocks' \
  && say "OK: rules match on the forwarded client address." \
  || { say "FAIL: no rule uses remoteIpBlocks / notRemoteIpBlocks."
       say "      ipBlocks matches the connection peer, which behind a proxy is the proxy."
       FAIL=1; }

kubectl -n istio-system port-forward svc/istio-ingressgateway 18080:80 >/dev/null 2>&1 &
PF_PIDS+=($!)
sleep 4

call() { curl -s -o /dev/null -w '%{http_code}' --max-time 15 \
  -H "Host: booking.ica.local" -H "X-Forwarded-For: $1" "http://127.0.0.1:18080$2" 2>/dev/null; }
expect() { if [ "$4" = "$3" ]; then say "OK: xff $1 $2 -> $4"; else
  say "FAIL: xff $1 $2 -> '${4:-no response}', expected $3."
  [ -n "${5:-}" ] && say "      $5"; FAIL=1; fi; }

say "--- check 2: the five graded requests ---"
expect 10.1.2.3    /book  200 "$(call 10.1.2.3 /book)" \
  "403 here usually means an ALLOW policy closed the whole gateway."
expect 192.168.5.5 /book  403 "$(call 192.168.5.5 /book)" \
  "The global block-list is missing or its CIDR is wrong."
expect 10.1.2.3    /admin 403 "$(call 10.1.2.3 /admin)" \
  "404 means the admin restriction did not fire — check for an inverted condition."
expect 192.168.5.5 /admin 403 "$(call 192.168.5.5 /admin)"

CODE=$(call 203.0.113.9 /admin)
if [ "$CODE" != "403" ] && [ -n "$CODE" ] && [ "$CODE" != "000" ]; then
  say "OK: xff 203.0.113.9 /admin -> $CODE (allowed through; the application answered)."
else
  say "FAIL: xff 203.0.113.9 /admin -> '${CODE:-no response}', expected anything but 403."
  say "      The office range is being denied too — the source condition is not inverted."
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
