#!/usr/bin/env bash
# Grading for LAB015-010-03 — migrate the last plaintext caller, then enforce STRICT.
set -uo pipefail

FAIL=0
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
# Istio 1.30 keeps every inbound filter chain inside the virtualInbound listener
# on 15006, so `--port 8084` matches no listener at all and the mTLS setting looks
# absent. Read the whole dump and find the chain for this workload's port.
REQ=$(istioctl proxy-config listener deploy/notification-service-v1 -n migrate-demo \
  -o json 2>/dev/null | python3 -c '
import json, sys
try:
    listeners = json.load(sys.stdin)
except Exception:
    print(0); sys.exit()
hits = 0
for l in listeners:
    for fc in l.get("filterChains", []):
        if fc.get("filterChainMatch", {}).get("destinationPort") != 8084:
            continue
        ts = fc.get("transportSocket", {}).get("typedConfig", {})
        if ts.get("requireClientCertificate"):
            hits += 1
print(hits)
')
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
