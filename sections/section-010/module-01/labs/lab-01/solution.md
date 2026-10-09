# Solution Walkthrough

Read the badge first, then require the handshake, then write the guest list. The last step proves the two callers get different answers for the reason you intended: a `403` from the guard, not a broken connection.

---

## Step 1: Find out who runs as what

Every badge (identity) is printed from a service account, the workload's registration papers. List them:

```sh
kubectl get pods -n identity-demo \
  -o custom-columns='POD:.metadata.name,SERVICE ACCOUNT:.spec.serviceAccountName'
```

```text
POD                                        SERVICE ACCOUNT
booking-service-v1-7974c59f5d-swlhb        booking-sa
notification-service-v1-54dd46d4b6-9glj2   default
tester-69699fd775-276jw                    default
```

`tester` runs as `default`, so a rule that names `default` would let the debugging pod straight in. The badge that sets the intended caller apart is `booking-sa`.

Check the starting behaviour too. Both callers get through:

```sh
kubectl exec -n identity-demo deploy/booking-service-v1 -c booking-service -- curl -s -o /dev/null -w "booking: %{http_code}\n" -X POST http://notification-service/notify
kubectl exec -n identity-demo deploy/tester -- curl -s -o /dev/null -w "tester:  %{http_code}\n" -X POST http://notification-service/notify
```

```text
booking: 200
tester:  200
```

---

## Step 2: Read the badge off the certificate

Do not build the name from memory. Take the certificate out of the booking proxy and read its SAN (Subject Alternative Name), the field that holds the identity:

```sh
istioctl proxy-config secret deploy/booking-service-v1 -n identity-demo -o json \
  | jq -r '.dynamicActiveSecrets[] | select(.name=="default") | .secret.tlsCertificate.certificateChain.inlineBytes' \
  | base64 --decode > booking.pem
openssl x509 -in booking.pem -noout -ext subjectAltName
```

```text
X509v3 Subject Alternative Name: critical
    URI:spiffe://cluster.local/ns/identity-demo/sa/booking-sa
```

The `principals` field takes the same name **without** `spiffe://`, because Istio adds that part itself:

```text
cluster.local/ns/identity-demo/sa/booking-sa
```

---

## Step 3: Require the handshake for the whole planet

`STRICT` mTLS means every caller must show its badge before it may talk to any workload in the namespace. A `PeerAuthentication` named `default` without a `selector` covers the whole namespace.

Save this as `peerauthentication-default.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: identity-demo
spec:
  mtls:
    mode: STRICT
```

Apply it:

```sh
kubectl apply -f peerauthentication-default.yaml
```

```text
peerauthentication.security.istio.io/default created
```

---

## Step 4: Write the guest list

An `ALLOW` policy that selects `notification-service` shuts out everyone it does not list. One rule with one principal is the only way in.

Save this as `authorizationpolicy-notification-by-identity.yaml`:

```yaml
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
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-notification-by-identity.yaml
```

```text
authorizationpolicy.security.istio.io/notification-by-identity created
```

---

## Step 5: Prove it

Send the same call from both workloads. Give the new rules up to a minute first: connections that were already open can keep the old rules for a short while.

```sh
kubectl exec -n identity-demo deploy/booking-service-v1 -c booking-service -- curl -s -o /dev/null -w "booking: %{http_code}\n" -X POST http://notification-service/notify
kubectl exec -n identity-demo deploy/tester -- curl -s -o /dev/null -w "tester:  %{http_code}\n" -X POST http://notification-service/notify
```

```text
booking: 200
tester:  403
```

Same request, same planet, same path. The only difference is the badge each caller showed during the handshake. The `notification-service` proxy turned `tester` away; the body of its answer is `RBAC: access denied`.

---

## Step 6: Submit

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

```text
PASS: identity-demo enforces STRICT mTLS, the policy matches the booking-sa principal, booking-service gets 200 and tester gets 403
PROCTOR: PASS
```

(Shortened to the result lines.)

---

## If it does not pass

- **`a principals value still carries the spiffe:// scheme`.** Remove `spiffe://` from the principal. Kubernetes accepts it, but the proxy then looks for `spiffe://spiffe://...`, and both callers get `403`.
- **Both callers get `200`.** The `selector` matches no pod, so no guard stands at the airlock. Check the label with `kubectl get pods -n identity-demo --show-labels`.
- **Both callers get `000`.** That is a broken connection, not the guard. Look at the `PeerAuthentication`, not the guest list.
- **`no PeerAuthentication ... STRICT for the whole namespace`.** The `PeerAuthentication` has a `selector`, or its mode is not `STRICT`.
