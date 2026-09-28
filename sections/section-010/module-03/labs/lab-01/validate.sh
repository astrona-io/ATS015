#!/usr/bin/env bash
# Grading for LAB015-010-03 — migrate the last plaintext caller, then enforce STRICT.
set -uo pipefail

FAIL=0
say() { printf '%s\n' "$*"; }

say "--- check 1: migrate-demo has a namespace-wide STRICT policy ---"
NSMODE=$(kubectl -n migrate-demo get peerauthentication -o json 2>/dev/null \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print(' '.join(i['spec'].get('mtls',{}).get('mode','') for i in d.get('items',[]) if 'selector' not in i['spec']))" 2>/dev/null)
case "$NSMODE" in
  *STRICT*) say "OK: namespace-wide STRICT found in migrate-demo." ;;
  *) say "FAIL: no selector-less STRICT PeerAuthentication in migrate-demo (found: '${NSMODE:-none}')."
     say "      A policy with a selector is a workload policy, which is not what the task asks for."
     FAIL=1 ;;
esac

say "--- check 2: outside-client now runs with a sidecar ---"
CONTAINERS=$(kubectl -n outside get pods -l app=outside-client \
  -o jsonpath='{.items[*].spec.initContainers[*].name} {.items[*].spec.containers[*].name}' 2>/dev/null)
case "$CONTAINERS" in
  *istio-proxy*) say "OK: outside-client has an istio-proxy container." ;;
  *) say "FAIL: outside-client has no sidecar (containers: '${CONTAINERS:-none}')."
     say "      Labelling the namespace is not enough — the pod must be recreated."
     FAIL=1 ;;
esac

say "--- check 3: the migrated caller still reaches notification-service ---"
CODE=$(kubectl -n outside exec deploy/outside-client -- \
  curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
  -X POST http://notification-service.migrate-demo/notify 2>/dev/null)
if [ "$CODE" = "200" ]; then
  say "OK: outside-client -> notification-service returned 200."
else
  say "FAIL: outside-client -> notification-service returned '${CODE:-no response}', expected 200."
  say "      A 000 means it is still sending plaintext to a STRICT server."
  FAIL=1
fi

say "--- check 4: the in-mesh caller is unaffected ---"
CODE=$(kubectl -n migrate-demo exec deploy/tester -- \
  curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
  -X POST http://notification-service/notify 2>/dev/null)
if [ "$CODE" = "200" ]; then
  say "OK: tester -> notification-service returned 200."
else
  say "FAIL: tester -> notification-service returned '${CODE:-no response}', expected 200."
  FAIL=1
fi

say "--- check 5: the receiving listener really requires a client certificate ---"
REQ=$(istioctl proxy-config listener deploy/notification-service-v1 -n migrate-demo \
  --port 8084 -o json 2>/dev/null | grep -ci '"requireClientCertificate": true')
if [ "${REQ:-0}" -ge 1 ]; then
  say "OK: requireClientCertificate is true on port 8084."
else
  say "FAIL: the inbound listener on port 8084 does not require a client certificate."
  say "      The policy exists but did not reach this workload's proxy."
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
