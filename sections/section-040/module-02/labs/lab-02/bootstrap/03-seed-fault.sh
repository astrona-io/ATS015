#!/usr/bin/env bash
# The lab's starting state: a MUTUAL gateway that trusts the wrong CA.
#
# Makes, on this machine, in /tmp/ats-015-lab-040-02-02/:
#   example.com.crt                          the trusted CA (the RIGHT one)
#   starfleet.example.com.crt / .key         the gateway's server certificate (signed by example.com)
#   partner.crt / .key                       the trusted partner's client certificate (signed by example.com)
#   other-ca.crt                             another CA, not trusted
#   stranger.crt / .key                      a client certificate signed by other-ca
# The CA private keys are deleted after signing.
#
# Then creates the secret starfleet-credential-mutual in istio-ingress with the
# right server certificate but ca.crt = other-ca.crt, a MUTUAL Gateway that
# uses it, and a correct VirtualService for the bridge. Result: the partner is
# refused in the handshake and the stranger gets 200.
# Fixing the secret's ca.crt is the task - the Gateway and VirtualService are correct.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail

CERT_DIR="/tmp/ats-015-lab-040-02-02"
command -v openssl >/dev/null 2>&1 || { echo "openssl is required on this machine" >&2; exit 1; }

echo "==> Certificates in $CERT_DIR"
rm -rf "$CERT_DIR"
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

# The trusted CA, the gateway's server certificate and the partner's client certificate.
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
  -subj '/O=example Inc./CN=example.com' -keyout example.com.key -out example.com.crt 2>/dev/null
openssl req -out starfleet.example.com.csr -newkey rsa:2048 -nodes -keyout starfleet.example.com.key \
  -subj "/CN=starfleet.example.com/O=starfleet organization" 2>/dev/null
printf "subjectAltName=DNS:starfleet.example.com\n" > san.ext
openssl x509 -req -sha256 -days 365 -CA example.com.crt -CAkey example.com.key -set_serial 0 \
  -in starfleet.example.com.csr -out starfleet.example.com.crt -extfile san.ext 2>/dev/null
openssl req -out partner.csr -newkey rsa:2048 -nodes -keyout partner.key \
  -subj "/CN=partner.example.com/O=partner organization" 2>/dev/null
openssl x509 -req -sha256 -days 365 -CA example.com.crt -CAkey example.com.key -set_serial 1 \
  -in partner.csr -out partner.crt 2>/dev/null

# Another CA (other-ca) and a client certificate it signed.
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
  -subj '/O=Other Inc./CN=other-ca' -keyout other-ca.key -out other-ca.crt 2>/dev/null
openssl req -out stranger.csr -newkey rsa:2048 -nodes -keyout stranger.key \
  -subj "/CN=stranger/O=other" 2>/dev/null
openssl x509 -req -sha256 -days 365 -CA other-ca.crt -CAkey other-ca.key -set_serial 2 \
  -in stranger.csr -out stranger.crt 2>/dev/null

rm -f example.com.key other-ca.key ./*.csr ./*.srl san.ext
chmod 600 ./*.key
ls -l "$CERT_DIR"

echo "==> The gate's secret (with the wrong CA)"
kubectl create -n istio-ingress secret generic starfleet-credential-mutual \
  --from-file=tls.key=starfleet.example.com.key \
  --from-file=tls.crt=starfleet.example.com.crt \
  --from-file=ca.crt=other-ca.crt \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Gateway and VirtualService"
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
    - starfleet.example.com
    tls:
      mode: MUTUAL
      credentialName: starfleet-credential-mutual
YAML

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
    route:
    - destination:
        host: bridge
        port:
          number: 9080
YAML

kubectl get gateway.networking.istio.io,virtualservice -n starfleet
echo "==> Lab ats-015-lab-040-02-02 ready"
