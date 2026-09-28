#!/usr/bin/env bash
# Grading for LAB015-010-02 — PeerAuthentication at mesh, namespace and workload scope.
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

say "--- check 1: a mesh-wide STRICT policy exists in the root namespace ---"
MESH=$(kubectl -n istio-system get peerauthentication -o json 2>/dev/null \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print(' '.join(i['spec'].get('mtls',{}).get('mode','') for i in d.get('items',[]) if 'selector' not in i['spec']))" 2>/dev/null)
case "$MESH" in
  *STRICT*) say "OK: mesh-wide STRICT found in istio-system." ;;
  *) say "FAIL: no selector-less STRICT PeerAuthentication in istio-system (found: '${MESH:-none}')."; FAIL=1 ;;
esac

say "--- check 2: a namespace-wide PERMISSIVE exception exists in mtls-demo ---"
NSMODE=$(kubectl -n mtls-demo get peerauthentication -o json 2>/dev/null \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print(' '.join(i['spec'].get('mtls',{}).get('mode','') for i in d.get('items',[]) if 'selector' not in i['spec']))" 2>/dev/null)
case "$NSMODE" in
  *PERMISSIVE*) say "OK: namespace-wide PERMISSIVE found in mtls-demo." ;;
  *) say "FAIL: no selector-less PERMISSIVE PeerAuthentication in mtls-demo (found: '${NSMODE:-none}')."; FAIL=1 ;;
esac

say "--- check 3: a workload-scoped STRICT policy exists in mtls-demo ---"
WL=$(kubectl -n mtls-demo get peerauthentication -o json 2>/dev/null \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print(' '.join(i['spec'].get('mtls',{}).get('mode','') for i in d.get('items',[]) if 'selector' in i['spec']))" 2>/dev/null)
case "$WL" in
  *STRICT*) say "OK: workload-scoped STRICT found in mtls-demo." ;;
  *) say "FAIL: no PeerAuthentication with a selector and mode STRICT in mtls-demo."; FAIL=1 ;;
esac

say "--- check 4: the plaintext caller is refused by notification-service ---"
CODE=$(kubectl -n outside exec deploy/outside-client -- \
  curl -s -o /dev/null -w '%{http_code}' --max-time 8 \
  -X POST http://notification-service.mtls-demo/notify 2>/dev/null)
if [ "$CODE" = "000" ] || [ -z "$CODE" ]; then
  say "OK: outside-client -> notification-service was refused at the transport."
else
  say "FAIL: outside-client -> notification-service returned '$CODE', expected a refused connection."
  say "      The workload-scoped STRICT policy is not reaching those pods — check its selector."
  FAIL=1
fi

say "--- check 5: the plaintext caller still reaches booking-service ---"
CODE=$(kubectl -n outside exec deploy/outside-client -- \
  curl -s -o /dev/null -w '%{http_code}' --max-time 8 \
  -X POST http://booking-service.mtls-demo/book 2>/dev/null)
if [ "$CODE" = "200" ]; then
  say "OK: outside-client -> booking-service returned 200."
else
  say "FAIL: outside-client -> booking-service returned '${CODE:-no response}', expected 200."
  say "      The namespace PERMISSIVE exception is missing, or the workload policy is too wide."
  FAIL=1
fi

say "--- check 6: the in-mesh caller is unaffected ---"
CODE=$(kubectl -n mtls-demo exec deploy/tester -- \
  curl -s -o /dev/null -w '%{http_code}' --max-time 8 \
  -X POST http://notification-service/notify 2>/dev/null)
if [ "$CODE" = "200" ]; then
  say "OK: tester -> notification-service returned 200."
else
  say "FAIL: tester -> notification-service returned '${CODE:-no response}', expected 200."
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
