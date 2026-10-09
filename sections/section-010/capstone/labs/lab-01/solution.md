# Solution Walkthrough

Mission debrief, astronaut. The whole capstone is about order. You bring the ship without a badge into the mesh first, then require the handshake for the whole fleet, and only then put a guard on the notification service.

---

## Step 1: Measure first

Send a few plain-text signals from the outside ship, then ask booking-service's communications officer how its incoming signals arrived:

```sh
kubectl -n outside exec deploy/outside-client -- sh -c \
  'for i in $(seq 1 5); do curl -s -o /dev/null -X POST http://booking-service.identity-demo/book; done'
kubectl -n identity-demo exec deploy/booking-service-v1 -c istio-proxy -- \
  pilot-agent request GET stats/prometheus 2>/dev/null | grep istio_requests_total \
  | grep -o 'connection_security_policy="[^"]*"' | sort | uniq -c
```

```text
   1 connection_security_policy="none"
   1 connection_security_policy="unknown"
```

Each line is one request counter of booking-service's communications officer, not one request. The `none` counter is for signals that arrived with no handshake at all. Those come from `outside-client`. The `unknown` counter is for the signals booking-service itself sends on to notification-service: the sending side does not record how they were sealed.

The `none` line is the warning. If you start with the mesh-wide `STRICT` rule, the officer turns those plain-text signals away.

---

## Step 2: Bring the outside ship into the mesh

Sidecar injection puts a communications officer on board when a ship launches. Ships already flying do not get one. So the namespace label alone changes nothing for the running pod. You also have to restart it:

```sh
kubectl label namespace outside istio-injection=enabled
kubectl -n outside rollout restart deployment outside-client
kubectl -n outside rollout status deployment outside-client
kubectl -n outside get pods -o custom-columns='POD:.metadata.name,INIT:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name'
```

```text
POD                               INIT                     CONTAINERS
outside-client-5d765f547f-cd645   <none>                   outside-client
outside-client-7bc45d7f7d-pgb4z   istio-init,istio-proxy   outside-client
```

The old pod, with no communications officer, takes about 30 seconds to stop, so you may still see it for a moment. Run the last command again until only the new pod is left.

The new pod has `istio-proxy` in the `INIT` column. That is the communications officer. Istio 1.30 starts it as a native sidecar: a helper container that Kubernetes starts first and keeps running next to the app. So it shows up under `INIT`, not under `CONTAINERS`, and `kubectl get pods` shows the pod as `2/2` ready. This was the step that could break something, and you did it first on purpose.

---

## Step 3: Require the handshake for the whole fleet

The mesh scope has one home: the root namespace `istio-system`, with no `selector`. Put the same object in any other namespace, and it quietly becomes a rule for that one planet.

Save this as `peerauthentication-default.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
```

Apply it:

```sh
kubectl apply -f peerauthentication-default.yaml
```

Then check the result. A new rule can take up to about a minute to reach connections that are already open, so wait a minute before you trust the answer:

```sh
kubectl -n outside exec deploy/outside-client -- \
  curl -s -o /dev/null -w 'outside -> booking: %{http_code}\n' --max-time 5 \
  -X POST http://booking-service.identity-demo/book
```

```text
outside -> booking: 200
```

Still `200`, because the outside ship now has a communications officer who does the handshake for it. If you had applied this rule before Step 2, the answer would be `000`, with curl exit code `56`: the receiving officer resets the connection before any HTTP answer.

---

## Step 4: Read the identity from the live badge

Do not type the identity from memory. Read it off the certificate that booking-service's communications officer really holds:

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

The SAN (Subject Alternative Name) is the name printed on the badge. The `principals` field takes the same value without the `spiffe://` prefix.

---

## Step 5: Put the guard on the notification service

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

Matching on the namespace would not work here. `tester` also lives in `identity-demo`, so a namespace rule would let it in too.

---

## Step 6: Prove all three calls

Wait about a minute after the last apply, then send the three signals:

```sh
kubectl -n identity-demo exec deploy/booking-service-v1 -c booking-service -- \
  curl -s -o /dev/null -w 'booking -> notify: %{http_code}\n' -X POST http://notification-service/notify
kubectl -n identity-demo exec deploy/tester -- \
  curl -s -o /dev/null -w 'tester  -> notify: %{http_code}\n' -X POST http://notification-service/notify
kubectl -n outside exec deploy/outside-client -- \
  curl -s -o /dev/null -w 'outside -> book:   %{http_code}\n' --max-time 5 -X POST http://booking-service.identity-demo/book
```

```text
booking -> notify: 200
tester  -> notify: 403
outside -> book:   200
```

Two successes and one refusal. The refusal is a `403`: the guard turned the signal away at the airlock. It is not a `000`, which would mean the handshake failed. Those two failures come from different objects, so always check which one you got.

Now submit:

```sh
astrona submit -c sections/section-010/capstone/labs/lab-01
```

---

## Common Mistakes

- **Applying the mesh-wide `STRICT` rule first.** `outside-client` still sends plain text, so its calls fail with `000` until it gets a sidecar.
- **Labelling the namespace without restarting.** The label only affects new pods. The running `outside-client` keeps flying without a communications officer.
- **Putting the `PeerAuthentication` in `identity-demo`.** That makes it a namespace rule. The grader looks for it in `istio-system`, named `default`, with no `selector`.
- **Leaving `spiffe://` in the principal.** The rule then matches nobody, and booking-service gets `403` too.
- **Matching on `namespaces` instead of `principals`.** `tester` lives in the same namespace and would get `200`.
