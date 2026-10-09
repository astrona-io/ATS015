#!/usr/bin/env bash
# Grading for ats-015-lab-010-02 - PeerAuthentication at mesh, namespace and
# workload scope. Confirms the three policies exist at the right scopes, then
# sends real traffic from the plain-text caller (outside-client, no sidecar)
# and from the meshed caller (tester) and checks each outcome.

set -u

fail() { echo "FAIL: $*"; exit 1; }

# Applying the end state and grading it in the same second is a race: pods that
# are being replaced are still listed, and `kubectl exec deploy/x` may pick the
# one on its way out. Wait until every workload outside the system namespaces
# is settled before reading behaviour.
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

# Modes of the PeerAuthentications in one namespace, with or without a selector.
modes_without_selector() {
  kubectl -n "$1" get peerauthentication -o go-template='{{range .items}}{{if not .spec.selector}}{{.spec.mtls.mode}} {{end}}{{end}}' 2>/dev/null
}

# --- 0. the starting workloads are still there --------------------------------
for d in booking-service-v1 notification-service-v1 tester; do
  ready=$(kubectl -n mtls-demo get deployment "$d" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [[ -n "$ready" && "$ready" -ge 1 ]] || fail "deployment $d in mtls-demo is missing or not ready. Do not change the workloads"
done
ready=$(kubectl -n outside get deployment outside-client -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[[ -n "$ready" && "$ready" -ge 1 ]] || fail "deployment outside-client in outside is missing or not ready. It is the only plain-text caller and grading needs it"
injected=$(kubectl -n outside get pods -l app=outside-client -o jsonpath='{.items[*].spec.containers[*].name}' 2>/dev/null)
grep -q istio-proxy <<<"$injected" && fail "outside-client now has a sidecar. Leave it outside the mesh"

# --- 1. mesh-wide STRICT --------------------------------------------------------
kubectl -n istio-system get peerauthentication default >/dev/null 2>&1 \
  || fail "peerauthentication/default not found in istio-system. A mesh-wide policy lives in the root namespace"
mesh=$(modes_without_selector istio-system)
grep -qw STRICT <<<"$mesh" || fail "no PeerAuthentication without a selector and with mode STRICT in istio-system (found: '${mesh:-none}')"
echo "OK: mesh-wide STRICT in istio-system"

# --- 2. namespace-wide PERMISSIVE in mtls-demo --------------------------------
kubectl -n mtls-demo get peerauthentication default >/dev/null 2>&1 \
  || fail "peerauthentication/default not found in mtls-demo. The namespace exception lives in mtls-demo with no selector"
ns=$(modes_without_selector mtls-demo)
grep -qw PERMISSIVE <<<"$ns" || fail "no PeerAuthentication without a selector and with mode PERMISSIVE in mtls-demo (found: '${ns:-none}')"
echo "OK: namespace-wide PERMISSIVE in mtls-demo"

# --- 3. workload STRICT for notification-service --------------------------------
wl=$(kubectl -n mtls-demo get peerauthentication -o go-template='{{range .items}}{{if .spec.selector}}{{.spec.selector.matchLabels.app}}={{.spec.mtls.mode}} {{end}}{{end}}' 2>/dev/null)
grep -qw 'notification-service=STRICT' <<<"$wl" \
  || fail "no PeerAuthentication in mtls-demo with selector app: notification-service and mode STRICT (found: '${wl:-none}')"
echo "OK: workload STRICT for notification-service"

# --- 4. live traffic -----------------------------------------------------------
call() {  # $1 = namespace, $2 = deployment, $3 = URL; prints the HTTP code (000 = no answer)
  local code
  code=$(kubectl -n "$1" exec "deploy/$2" -- curl -s -o /dev/null -w '%{http_code}' --max-time 8 -X POST "$3" 2>/dev/null)
  echo "${code:-000}"
}
expect() {  # $1 = wanted code, rest = call args; retries while the new configuration reaches the proxies
  local want=$1 got i; shift
  for i in $(seq 1 45); do
    got=$(call "$@")
    [[ "$got" == "$want" ]] && { echo "$got"; return 0; }
    sleep 2
  done
  echo "$got"; return 1
}

got=$(expect 000 outside outside-client http://notification-service.mtls-demo/notify) \
  || fail "outside-client -> notification-service returned '$got', expected a refused connection (000). The workload STRICT policy is not reaching those pods - check its selector"
echo "OK: outside-client -> notification-service refused at the transport"

got=$(expect 200 outside outside-client http://booking-service.mtls-demo/book) \
  || fail "outside-client -> booking-service returned '$got', expected 200. The namespace PERMISSIVE exception is missing, or the workload policy is too wide"
echo "OK: outside-client -> booking-service returned 200"

got=$(expect 200 mtls-demo tester http://notification-service/notify) \
  || fail "tester -> notification-service returned '$got', expected 200. The meshed caller must keep working"
echo "OK: tester -> notification-service returned 200"

echo "PASS: mesh-wide STRICT, a PERMISSIVE exception for mtls-demo, and notification-service STRICT again; only the plain-text call to notification-service is refused"
exit 0
