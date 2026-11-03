#!/usr/bin/env bash
# Grading for ats-015-lab-010-04 - plug-in CA and per-workload certificate lifetime.
# Reads the cacerts Secret, then reads the certificate chain that the sidecar of
# probe-long and of probe-short presents (openssl s_client run inside shuttle's
# istio-proxy container), and checks with openssl:
#   both leaf certificates verify against ca-cert.pem + root-cert.pem from the Secret
#   probe-short's certificate expires within 4 hours; probe-long's does not
set -u

NS="ca-demo"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

fail() { echo "FAIL: $*"; exit 1; }

decode() { base64 -d 2>/dev/null || base64 -D; }

settle_dataplane() {
  local i pending
  for i in $(seq 1 60); do
    pending=$(kubectl -n "$NS" get pods \
      -o jsonpath='{range .items[*]}{.metadata.deletionTimestamp}{" "}{range .status.containerStatuses[*]}{.ready}{","}{end}{"\n"}{end}' 2>/dev/null \
      | awk 'NF>1 || $0 ~ /false/')
    [ -z "$pending" ] && return 0
    sleep 2
  done
}

# leaf_of <service>: saves the first certificate of the presented chain as $W/<service>.pem
leaf_of() {
  local svc="$1"
  kubectl -n "$NS" exec deploy/shuttle -c istio-proxy -- \
    openssl s_client -showcerts -connect "$svc.$NS:8000" </dev/null 2>/dev/null \
    | awk -v out="$W/$svc.pem" '/BEGIN CERTIFICATE/{n++; f=1} f && n==1{print > out} /END CERTIFICATE/{f=0}'
  [ -s "$W/$svc.pem" ]
}

for d in probe-long probe-short shuttle; do
  ready=$(kubectl -n "$NS" get deployment "$d" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ -n "$ready" ] && [ "$ready" -ge 1 ] || fail "$d - deployment missing or has no ready replicas in $NS"
done
mode=$(kubectl -n "$NS" get peerauthentication default -o jsonpath='{.spec.mtls.mode}' 2>/dev/null)
[ "$mode" = "STRICT" ] || fail "the PeerAuthentication 'default' in $NS is not STRICT. Leave it unchanged"

settle_dataplane

# --- 1. the Secret ----------------------------------------------------------------
for k in ca-cert.pem ca-key.pem root-cert.pem cert-chain.pem; do
  v=$(kubectl -n istio-system get secret cacerts -o "jsonpath={.data.${k//./\\.}}" 2>/dev/null)
  [ -n "$v" ] || fail "the Secret cacerts in istio-system is missing the key $k"
  printf '%s' "$v" | decode > "$W/$k"
done
echo "OK: cacerts has the four keys"
openssl x509 -in "$W/ca-cert.pem" -noout >/dev/null 2>&1 || fail "ca-cert.pem in cacerts is not a valid certificate"
openssl verify -CAfile "$W/root-cert.pem" "$W/ca-cert.pem" >/dev/null 2>&1 \
  || fail "ca-cert.pem is not signed by root-cert.pem"
echo "OK: the intermediate is signed by the root"
cat "$W/ca-cert.pem" "$W/root-cert.pem" > "$W/bundle.pem"

# --- 2. the certificates the sidecars present -------------------------------------
# New certificates arrive after the restarts. Retry each check for up to 120 s.
check_chain() {  # $1 = service
  local i
  for i in $(seq 1 60); do
    if leaf_of "$1" && openssl verify -CAfile "$W/bundle.pem" "$W/$1.pem" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}
check_chain probe-long  || fail "the certificate of probe-long does not verify against the CA in cacerts. Restart istiod, then restart the workloads, and wait for 2/2 pods"
echo "OK: probe-long certificate verifies against your CA"
check_chain probe-short || fail "the certificate of probe-short does not verify against the CA in cacerts. Restart the workloads after istiod"
echo "OK: probe-short certificate verifies against your CA"

# --- 3. lifetimes -----------------------------------------------------------------
openssl x509 -in "$W/probe-short.pem" -noout -checkend 14400 >/dev/null 2>&1 \
  && fail "the certificate of probe-short does not expire within four hours. Set SECRET_TTL in proxy.istio.io/config on the pod template, and restart its pods"
openssl x509 -in "$W/probe-short.pem" -noout -checkend 0 >/dev/null 2>&1 \
  || fail "the certificate of probe-short has already expired"
echo "OK: probe-short certificate expires within four hours"
openssl x509 -in "$W/probe-long.pem" -noout -checkend 14400 >/dev/null 2>&1 \
  || fail "the certificate of probe-long expires within four hours. Leave probe-long at the default lifetime"
echo "OK: probe-long certificate has the default lifetime"

echo "PASS: workload certificates chain to your CA, and only probe-short is short-lived"
exit 0
