#!/usr/bin/env bash
# The lab's starting state: an HTTPS door to the bridge, broken in two places.
#   1. The TLS Secret starfleet-credential is in namespace starfleet (where the
#      Gateway lives), not in istio-ingress (where the gateway POD runs), so
#      the gateway never receives it.
#   2. The Gateway serves the host bridge.example.com instead of
#      starfleet.example.com, so the SNI starfleet.example.com matches no server.
# The certificate itself is correct: a server certificate for
# starfleet.example.com (SAN included), signed by a test CA. The CA certificate
# is left in the ConfigMap starfleet-ca so the learner (and the grader) can
# trust it with curl --cacert. The bridge VirtualService is correct.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

echo "==> Test CA and server certificate for starfleet.example.com"
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
  -subj '/O=Starfleet Command/CN=starfleet-ca' \
  -keyout starfleet-ca.key -out starfleet-ca.crt 2>/dev/null
openssl req -newkey rsa:2048 -nodes -keyout starfleet.example.com.key \
  -subj '/O=Starfleet/CN=starfleet.example.com' -out starfleet.example.com.csr 2>/dev/null
printf "subjectAltName=DNS:starfleet.example.com\n" > san.ext
openssl x509 -req -sha256 -days 365 -CA starfleet-ca.crt -CAkey starfleet-ca.key \
  -set_serial 1 -in starfleet.example.com.csr -out starfleet.example.com.crt \
  -extfile san.ext 2>/dev/null

echo "==> The CA, for clients to trust"
kubectl create configmap starfleet-ca -n starfleet --from-file=ca.crt=starfleet-ca.crt \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Fault 1: the TLS Secret on the wrong planet"
kubectl create secret tls starfleet-credential -n starfleet \
  --key=starfleet.example.com.key --cert=starfleet.example.com.crt \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Fault 2: a Gateway that serves the wrong host"
kubectl apply -f - <<'YAML'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: starfleet-gateway
  namespace: starfleet
spec:
  selector:
    istio: ingress
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - bridge.example.com
    tls:
      mode: SIMPLE
      credentialName: starfleet-credential
YAML

echo "==> The bridge VirtualService (correct)"
kubectl apply -f - <<'YAML'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: bridge
  namespace: starfleet
spec:
  hosts:
  - starfleet.example.com
  gateways:
  - starfleet-gateway
  http:
  - match:
    - uri:
        exact: /productpage
    - uri:
        prefix: /static
    - uri:
        exact: /login
    - uri:
        exact: /logout
    - uri:
        prefix: /api/v1/products
    route:
    - destination:
        host: bridge
        port:
          number: 9080
YAML

kubectl get gateway,virtualservice,secret,configmap -n starfleet
