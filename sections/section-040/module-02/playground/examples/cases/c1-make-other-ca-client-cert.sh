#!/usr/bin/env bash
# Case 1 helper: a client certificate signed by a DIFFERENT CA (other-ca),
# written to certs/other-client.*. The gateway only trusts the example.com CA.
# Run it from the folder where you created certs/.
set -euo pipefail
cd certs
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
  -subj '/O=Other Inc./CN=other-ca' -keyout other-ca.key -out other-ca.crt 2>/dev/null
openssl req -out other-client.csr -newkey rsa:2048 -nodes -keyout other-client.key \
  -subj "/CN=other-client/O=other" 2>/dev/null
openssl x509 -req -sha256 -days 365 -CA other-ca.crt -CAkey other-ca.key -set_serial 2 \
  -in other-client.csr -out other-client.crt 2>/dev/null
echo "created certs/other-client.crt and certs/other-client.key"
