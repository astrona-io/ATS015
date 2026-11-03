#!/usr/bin/env bash
# Grading for ats-015-lab-020-04 - external authorization with a CUSTOM policy.
# Checks the mesh configuration has an HTTP extension provider that sends x-ext-authz,
# that a CUSTOM policy selects the probe, then sends real requests from the shuttle:
#   /headers, no header            403
#   /headers, x-ext-authz: deny    403
#   /headers, x-ext-authz: allow   200
#   /ip, no header                 200
set -u

NS="starfleet"
PROBE="http://probe:8000"

fail() { echo "FAIL: $*"; exit 1; }

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

code() {  # $@ = extra curl args; prints the status code
  kubectl -n "$NS" exec deploy/shuttle -c shuttle -- \
    curl -s -o /dev/null -m 5 -w "%{http_code}" "$@" 2>/dev/null
}

# The mesh configuration reaches the proxies after a delay. Retry up to 90 s.
expect_code() {  # $1 = expected code, rest = curl args
  local want="$1" i got=""; shift
  for i in $(seq 1 45); do
    got=$(code "$@")
    [ "$got" = "$want" ] && return 0
    sleep 2
  done
  echo "last status: ${got:-none}"
  return 1
}

for d in probe-v1 probe-v2 shuttle ext-authz; do
  ready=$(kubectl -n "$NS" get deployment "$d" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ -n "$ready" ] && [ "$ready" -ge 1 ] || fail "$d - deployment missing or has no ready replicas in $NS. Do not change the Deployments"
done
mode=$(kubectl -n "$NS" get peerauthentication default -o jsonpath='{.spec.mtls.mode}' 2>/dev/null)
[ "$mode" = "STRICT" ] || fail "the PeerAuthentication 'default' in $NS is not STRICT. Leave it unchanged"

settle_dataplane

# --- 1. configuration exists ------------------------------------------------------
mesh=$(kubectl -n istio-system get configmap istio -o jsonpath='{.data.mesh}' 2>/dev/null)
grep -q 'extensionProviders' <<<"$mesh" || fail "the mesh configuration has no extensionProviders. Add the provider to the 'mesh' key of the ConfigMap istio in istio-system"
grep -q 'starfleet-authz' <<<"$mesh" || fail "no extension provider named starfleet-authz in the mesh configuration"
grep -q 'envoyExtAuthzHttp' <<<"$mesh" || fail "the provider must use the HTTP type envoyExtAuthzHttp"
grep -q 'x-ext-authz' <<<"$mesh" || fail "the provider does not send the x-ext-authz header (includeRequestHeadersInCheck)"
grep -qE '^[[:space:]]*(accessLogFile|defaultConfig|enablePrometheusMerge|trustDomain)' <<<"$mesh" \
  || fail "the other settings of the mesh configuration are gone. Append to the existing value, do not replace it"
echo "OK: the mesh configuration has the HTTP provider starfleet-authz and keeps its other settings"

actions=$(kubectl -n "$NS" get authorizationpolicy -o jsonpath='{.items[*].spec.action}' 2>/dev/null)
case " $actions " in *" CUSTOM "*) ;; *) fail "no CUSTOM policy in $NS (actions found: '${actions:-none}')" ;; esac
case " $actions " in *" ALLOW "*|*" DENY "*) fail "an ALLOW or DENY policy exists. Use only a CUSTOM policy" ;; esac
provider=$(kubectl -n "$NS" get authorizationpolicy -o jsonpath='{.items[*].spec.provider.name}' 2>/dev/null)
case " $provider " in *" starfleet-authz "*) ;; *) fail "the CUSTOM policy does not use the provider starfleet-authz (found: '${provider:-none}')" ;; esac
echo "OK: a CUSTOM policy uses starfleet-authz"

# --- 2. behaviour -----------------------------------------------------------------
out=$(expect_code 403 "$PROBE/headers") || fail "/headers without the header did not give 403. $out"
echo "OK: /headers without the header -> 403"

out=$(expect_code 403 -H "x-ext-authz: deny" "$PROBE/headers") || fail "/headers with x-ext-authz: deny did not give 403. $out"
echo "OK: /headers with deny -> 403"

out=$(expect_code 200 -H "x-ext-authz: allow" "$PROBE/headers") || fail "/headers with x-ext-authz: allow did not give 200. Check includeRequestHeadersInCheck and the provider port. $out"
echo "OK: /headers with allow -> 200"

out=$(expect_code 200 "$PROBE/ip") || fail "/ip did not give 200. The CUSTOM rule must match /headers only. $out"
echo "OK: /ip -> 200"

echo "PASS: only /headers is checked by the external authorizer"
exit 0
