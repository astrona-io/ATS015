# Step-by-Step Guide: LAB015-010-01

> The full answer. Try the [exam question](./exam-question.md) first.

## Step 1: Find out who is who

```sh
kubectl -n identity-demo get pods \
  -o custom-columns='POD:.metadata.name,SA:.spec.serviceAccountName'
```

```text
POD                                       SA
booking-service-v1-7c9f8d6b4-kq2wv        booking-sa
notification-service-v1-5d8c7b9f6-x4m2p   default
tester-6b4d9c8f7-h8trn                    default
```

`notification-service-v1` and `tester` both run as `default`, so a rule naming
`default` would let the debugging pod straight through. The identity that
distinguishes the intended caller is `booking-sa`.

## Step 2: Read the identity off the certificate

Do not assemble the string from memory — read it:

```sh
istioctl proxy-config secret deploy/booking-service-v1 -n identity-demo -o json \
  | python3 -c "import sys,json,base64; d=json.load(sys.stdin); \
      c=[s for s in d['dynamicActiveSecrets'] if s['name']=='default'][0]; \
      print(base64.b64decode(c['secret']['tlsCertificate']['certificateChain']['inlineBytes']).decode())" \
  > /tmp/workload.crt

openssl x509 -in /tmp/workload.crt -noout -text | grep -A1 'Subject Alternative Name'
```

```text
            X509v3 Subject Alternative Name: critical
                URI:spiffe://cluster.local/ns/identity-demo/sa/booking-sa
```

The policy field takes the same value **without** the `spiffe://` scheme:

```text
cluster.local/ns/identity-demo/sa/booking-sa
```

## Step 3: Make identity verifiable

An identity-based rule matches a value taken from the client certificate. With
the namespace still `PERMISSIVE`, a plaintext caller presents no certificate, so
the field is empty and the rule can never match. Turn on `STRICT` first:

```sh
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: identity-demo
spec:
  mtls:
    mode: STRICT
YAML
```

## Step 4: Authorize on that identity

```sh
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: notification-by-identity
  namespace: identity-demo
spec:
  selector:
    matchLabels:
      app: notification-service
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/identity-demo/sa/booking-sa
YAML
```

This is an `ALLOW` policy selecting `notification-service`, so it creates
default-deny for that workload: the one rule is now the only way in.

## Step 5: Prove it

```sh
kubectl -n identity-demo exec deploy/booking-service-v1 -c booking-service -- \
  curl -s -o /dev/null -w 'booking: %{http_code}\n' -X POST http://notification-service/notify
kubectl -n identity-demo exec deploy/tester -- \
  curl -s -o /dev/null -w 'tester:  %{http_code}\n' -X POST http://notification-service/notify
```

```text
booking: 200
tester:  403
```

Identical request, identical namespace, identical method and path. The only
difference is the certificate presented during the handshake.

## Step 6: Submit

```sh
astrona submit -c .
```

## If it does not pass

- **Both callers get `403`.** The principal string is wrong. The most common
  cause is leaving `spiffe://` on the front — it is accepted, and matches
  nothing. Compare it against the SAN character by character.
- **Both callers get `200`.** The `selector` matches no pod, so nothing was
  compiled. Check the label with
  `kubectl -n identity-demo get pods --show-labels`.
- **Both callers get `000`.** That is a transport rejection, not authorization —
  something is wrong with the `PeerAuthentication`, not the policy.
