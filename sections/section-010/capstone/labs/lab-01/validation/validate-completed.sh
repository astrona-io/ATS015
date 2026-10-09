#!/usr/bin/env bash
# Grading for CAP015-010 — mesh-wide mTLS, a migrated caller, identity authorization.
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

say "--- check 1: a mesh-scoped STRICT policy exists ---"
if kubectl -n istio-system get peerauthentication default >/dev/null 2>&1; then
  say "OK: PeerAuthentication 'default' exists in istio-system."
else
  say "FAIL: no PeerAuthentication named 'default' in istio-system."
  FAIL=1
fi
MESH=$(kubectl -n istio-system get peerauthentication -o json 2>/dev/null \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print(' '.join(i['spec'].get('mtls',{}).get('mode','') for i in d.get('items',[]) if 'selector' not in i['spec']))" 2>/dev/null)
case "$MESH" in
  *STRICT*) say "OK: selector-less STRICT PeerAuthentication in istio-system." ;;
  *) say "FAIL: no mesh-scoped STRICT policy (found: '${MESH:-none}')."
     say "      A policy in identity-demo is a namespace policy, not a mesh one."
     FAIL=1 ;;
esac

say "--- check 2: outside-client was migrated into the mesh ---"
C=$(kubectl -n outside get pods -l app=outside-client -o jsonpath='{.items[*].spec.initContainers[*].name} {.items[*].spec.containers[*].name}' 2>/dev/null)
case "$C" in
  *istio-proxy*) say "OK: outside-client has a sidecar." ;;
  *) say "FAIL: outside-client has no sidecar (containers: '${C:-none}')."
     say "      Labelling the namespace does not touch pods that are already running."
     FAIL=1 ;;
esac

# A connection opened before the last change can keep the old rules for up to
# about a minute. Retry the three calls for up to 90 seconds until they all
# give the expected code, then judge the last round.
from_outside() {
  kubectl -n outside exec deploy/outside-client -- \
    curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@" 2>/dev/null
}
from_booking() {
  kubectl -n identity-demo exec deploy/booking-service-v1 -c booking-service -- \
    curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@" 2>/dev/null
}
from_tester() {
  kubectl -n identity-demo exec deploy/tester -- \
    curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@" 2>/dev/null
}
GOT_OUTSIDE=""; GOT_BOOKING=""; GOT_TESTER=""
for i in $(seq 1 18); do
  GOT_OUTSIDE=$(from_outside -X POST http://booking-service.identity-demo/book)
  GOT_BOOKING=$(from_booking -X POST http://notification-service/notify)
  GOT_TESTER=$(from_tester -X POST http://notification-service/notify)
  [ "$GOT_OUTSIDE $GOT_BOOKING $GOT_TESTER" = "200 200 403" ] && break
  sleep 5
done

say "--- check 3: the migrated caller still reaches booking-service ---"
if [ "$GOT_OUTSIDE" = "200" ]; then say "OK: outside-client -> booking-service -> 200"; else
  say "FAIL: outside-client -> booking-service -> '${GOT_OUTSIDE:-no response}', expected 200."
  say "      000 means it is still sending plaintext into a STRICT mesh."
  FAIL=1
fi

say "--- check 4: booking-sa may reach notification-service ---"
if [ "$GOT_BOOKING" = "200" ]; then say "OK: booking-service -> notification-service -> 200"; else
  say "FAIL: booking-service -> notification-service -> '${GOT_BOOKING:-no response}', expected 200."
  say "      403 usually means the principal string is wrong."
  FAIL=1
fi

say "--- check 5: another identity may not ---"
if [ "$GOT_TESTER" = "403" ]; then say "OK: tester -> notification-service -> 403"; else
  say "FAIL: tester -> notification-service -> '${GOT_TESTER:-no response}', expected 403."
  say "      200 means no ALLOW policy selects notification-service, or the rule is too wide."
  FAIL=1
fi

say "--- check 6: the rule is identity-based ---"
POL=$(kubectl -n identity-demo get authorizationpolicy -o yaml 2>/dev/null)
NPOL=$(kubectl -n identity-demo get authorizationpolicy -o name 2>/dev/null | wc -l | tr -d ' ')
if [ "$NPOL" -lt 1 ]; then
  say "FAIL: no AuthorizationPolicy exists in identity-demo."
  FAIL=1
fi
if printf '%s' "$POL" | grep -q 'principals' && ! printf '%s' "$POL" | grep -q 'spiffe://'; then
  say "OK: an AuthorizationPolicy matches on principals, without the spiffe:// scheme."
else
  say "FAIL: no clean principals-based rule found in identity-demo."
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then say "RESULT: FAIL"; exit 1; fi
say "RESULT: PASS"
exit 0
