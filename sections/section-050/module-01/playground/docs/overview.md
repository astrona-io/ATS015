# Overview: Authorize By Source IP At The Ingress Gateway (Playground)

This is a **playground**, not a lab: your training solar system, astronaut. It
starts a fresh cluster, installs Istio, an ingress gateway and the Starfleet,
and then waits. There is no task, no `astrona submit` and no pass or fail.
Explore, break things, `astrona destroy`, start over.

Here you guard the **ingress gateway**, the spaceport arrival gate: the one
door that signals from outside the solar system come through. You decide who
may pass by the address a signal comes from.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Istio 1.30.5**, installed with Helm. `istio-base` and `istiod` live in
  `istio-system`. `istiod` is mission control: it sends every proxy its orders.
- The **ingress gateway** on the planet `istio-ingress`. Its Deployment and
  its Service are both called `istio-ingress`, and its pods carry the label
  **`istio=ingress`**. A policy for the gate must live in `istio-ingress` and
  select that label.
- Mesh-wide **access logs**, so every proxy writes one line per signal. Read
  the gate's flight log with
  `kubectl logs -n istio-ingress deploy/istio-ingress --tail=1`.
- Namespace **`starfleet`** (the planet you work on), labelled for injection, with:
  - **The Starfleet**: `bridge` (the flagship page on `/productpage`, and its
    API on `/api/v1/products`), `cargo`, `navcom` and `scout` v1, v2 and v3.
  - **`probe`** v1 and v2 on port `8000`, an echo service. Its `/headers`
    page shows the headers that reached it.
  - **`shuttle`**, a client pod inside the mesh.
- A **`Gateway` and a `VirtualService`** for `starfleet.example.com` on port
  `80`. `/headers` goes to `probe`, everything else to `bridge`. They are
  ready-made so you can focus on the policies.
- **No `AuthorizationPolicy`**, and **`numTrustedProxies` is not set**: the
  gate does not trust any relay in front of it yet.

You also need `istioctl` 1.30.5 and `helm` on your own machine. `astrona run`
used `helm` to install Istio, so it is there already.

### Reaching the gateway

`kind` has no cloud load balancer, so nothing outside the cluster can reach
the gateway on its own. `astrona run` keeps two port forwards running for you.
A port forward is a tunnel from your machine into the cluster.

| Forward | Local | Goes to |
| --- | --- | --- |
| `ingress-http` | `http://127.0.0.1:8080` | the ingress gateway, port `80` |
| `ingress-https` | `https://127.0.0.1:8443` | the ingress gateway, port `443` (answers once a `Gateway` has an HTTPS server) |

Check them with `astrona port-forward list`. You do not need to start a
`kubectl port-forward` yourself.

The tunnel matters for this module. It ends **inside** the gateway pod, so
the gateway sees every signal arrive from `127.0.0.1`, not from your laptop.
Read the flight log before you trust any address range.

## Helpers

Paste this into each new terminal. `gate_status` sends one signal through the
gateway to a path and prints only the status code. A second argument is put
in the `X-Forwarded-For` header, the list of addresses a relay adds:

```sh
gate_status() {
  if [ -n "$2" ]; then
    curl -s -o /dev/null -w "%{http_code}\n" -H "Host: starfleet.example.com" \
      -H "X-Forwarded-For: $2" "http://127.0.0.1:8080$1"
  else
    curl -s -o /dev/null -w "%{http_code}\n" -H "Host: starfleet.example.com" \
      "http://127.0.0.1:8080$1"
  fi; }
gate_log() { kubectl logs -n istio-ingress deploy/istio-ingress --tail=${1:-1}; }
```

Use them like this: `gate_status /productpage`,
`gate_status /productpage 192.168.5.5`, then `gate_log`.

To see which client address the gateway decided on, ask it for its listener
settings. `xffNumTrustedHops` appears only when `numTrustedProxies` is set:

```sh
istioctl proxy-config listener deploy/istio-ingress -n istio-ingress -o json | grep xffNumTrustedHops
```

## Things to try

- Before you write any policy, send a signal and find the address the gateway
  sees, at the end of the `gate_log` line.
- Put a gateway policy in `starfleet` instead of `istio-ingress`. It is
  accepted and blocks nothing.
- Copy `istio: ingressgateway` from an older example into the selector. No pod
  on this Helm install has that label, so nothing is blocked.
- Write an `ipBlocks` allow-list for `10.0.0.0/8`, then for `127.0.0.1/32`.
  Compare.
- Write a `remoteIpBlocks` deny for `192.168.0.0/16` **before** you set
  `numTrustedProxies`, and send `gate_status /productpage 192.168.5.5`. It
  still passes: without trusted relays, the gateway ignores the header.
- Set `numTrustedProxies: 1`, restart the gateway and try again.
- Send two addresses: `gate_status /productpage "192.168.5.5, 10.1.2.3"`.
  Which one did the gateway use? Then try `numTrustedProxies: 2`.
- Open `/api/v1/products` to one network only, and check that
  `/productpage` stays open for everyone.
- Send a denied signal and look at the `bridge` flight log
  (`kubectl logs -n starfleet deploy/bridge-v1 -c istio-proxy --tail=3`). The
  signal never arrived there.
- Read which headers the gateway sent on to the probe, before and after you
  set `numTrustedProxies`:
  `curl -s -H "Host: starfleet.example.com" -H "X-Forwarded-For: 10.1.2.3" http://127.0.0.1:8080/headers`.

Exam-style practice tasks with solutions are at the end of this page.

## Start over without a new cluster

```sh
kubectl delete authorizationpolicy --all -n istio-ingress
kubectl delete authorizationpolicy --all -n starfleet
```

`numTrustedProxies` stays as you last set it. To remove it, run the
`helm upgrade istiod ...` command again with `numTrustedProxies: 0` in the
values file, then `kubectl rollout restart deployment/istio-ingress -n istio-ingress`.

## Playground not working?

- `astrona list` shows running environments. "already exists" means an old
  one is still there: `astrona destroy ats-015-playground-050-01`, then run
  again.
- The full log path is printed at the end of `astrona run` (`~/.astrona/logs/`).
- `kubectl` talks to another cluster:
  `kubectl config use-context kind-astro-ats-015-playground-050-01`.
- `gate_status` prints `000` or `404` right after a gateway restart: the port
  forward still points at the old pod for a moment. Check
  `astrona port-forward list` and wait about thirty seconds.

## When you're done

```sh
astrona destroy ats-015-playground-050-01
```

(`astrona destroy` takes the environment name, not the configuration path.)

## Practice tasks

Three exam-style missions for this playground, astronaut. Start the
playground first, and paste the helpers from
the Helpers section above. The solutions use them.

Try each task on your own first, then open the solution.

Tasks 1 and 2 need the gateway to trust one relay in front of it. Check it
first:

```sh
istioctl proxy-config listener deploy/istio-ingress -n istio-ingress -o json | grep xffNumTrustedHops
```

Once it is set, you see one line per HTTP listener (only port `80` at this point):

```text
                            "xffNumTrustedHops": 1,
```

If it prints nothing, set it. Save this as `values-istiod-topology.yaml`:

```yaml
meshConfig:
  defaultConfig:
    gatewayTopology:
      numTrustedProxies: 1
```

Apply it, then restart the gateway so it reads the new setting:

```sh
helm upgrade istiod istiod --repo https://istio-release.storage.googleapis.com/charts \
  --version 1.30.5 -n istio-system --reuse-values -f values-istiod-topology.yaml
kubectl rollout restart deployment/istio-ingress -n istio-ingress
kubectl rollout status deployment/istio-ingress -n istio-ingress
```

```text
Release "istiod" has been upgraded. Happy Helming!
NAME: istiod
LAST DEPLOYED: Fri Oct  9 13:09:55 2026
NAMESPACE: istio-system
STATUS: deployed
REVISION: 4
DESCRIPTION: Upgrade complete
...
deployment.apps/istio-ingress restarted
Waiting for deployment "istio-ingress" rollout to finish: 0 out of 1 new replicas have been updated...
Waiting for deployment "istio-ingress" rollout to finish: 1 old replicas are pending termination...
deployment "istio-ingress" successfully rolled out
```

We cut Helm's notes at the `...`. Your `REVISION` number depends on how often you ran the upgrade. Run the `istioctl proxy-config listener` check again; it must now print `"xffNumTrustedHops": 1`. Right after the restart the port forward points at the old pod for a moment, so wait about thirty seconds before you send signals.

### Task 1: block a range at the gate

> Signals whose original client address is in **`198.51.100.0/24`** must be
> refused at the ingress gateway with `403`. Every other client still reaches
> `starfleet.example.com`. Name the policy `block-range`.

<details><summary>Solution</summary>

The policy lives on the gateway's planet and selects the gateway pod. It uses
`remoteIpBlocks`, the client address the gateway took from `X-Forwarded-For`.
`ipBlocks` would only see the port forward (`127.0.0.1`).

Save this as `authorizationpolicy-block-range.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: block-range
  namespace: istio-ingress
spec:
  selector:
    matchLabels:
      istio: ingress
  action: DENY
  rules:
  - from:
    - source:
        remoteIpBlocks: ["198.51.100.0/24"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-block-range.yaml
```

Wait about a minute, so the gate gets its new orders. Then check the result:

```sh
gate_status /productpage 198.51.100.7
gate_status /productpage 10.1.2.3
```

```text
403
200
```

`DENY` only removes the range. An `ALLOW` policy would close the gate for
every signal its rules do not match.

Clean up before the next task:

```sh
kubectl delete -f authorizationpolicy-block-range.yaml
```

</details>

### Task 2: one path, one network

> Only clients from **`203.0.113.0/24`** may reach `/api/v1/products` (and
> anything below it) on `starfleet.example.com`. Everyone may still open
> `/productpage`. Name the policy `api-office-only`.

<details><summary>Solution</summary>

"Only X may reach this path" is a `DENY` for the path when the client is
**not** X. Save this as `authorizationpolicy-api-office-only.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: api-office-only
  namespace: istio-ingress
spec:
  selector:
    matchLabels:
      istio: ingress
  action: DENY
  rules:
  - to:
    - operation:
        hosts: ["starfleet.example.com"]
        paths: ["/api/v1/products*"]
    from:
    - source:
        notRemoteIpBlocks: ["203.0.113.0/24"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-api-office-only.yaml
```

`kubectl` prints a warning that the policy "will deny all traffic to TCP ports". That is normal for a `DENY` with HTTP fields: the gate only speaks HTTP here, so nothing extra is blocked. Wait about a minute. Then check the result:

```sh
gate_status /api/v1/products 203.0.113.7
gate_status /api/v1/products 10.1.2.3
gate_status /productpage 10.1.2.3
```

```text
200
403
200
```

An `ALLOW` policy for the path and the range would also let the office in,
but it would refuse `/productpage` for everyone: once an `ALLOW` policy
selects the gateway, a signal that matches none of its rules is refused.

Clean up before the next task:

```sh
kubectl delete -f authorizationpolicy-api-office-only.yaml
```

</details>

### Task 3: the policy covers HTTPS too

> Add an HTTPS server on port `443` for `starfleet.example.com` to the
> `starfleet-gateway`, with a self-signed certificate in a secret named
> `starfleet-credential`. Then show that one `DENY` policy on the gateway pod
> refuses `192.168.0.0/16` on **both** port `80` and port `443`.

<details><summary>Solution</summary>

Create the certificate on your own machine. This writes `starfleet.key` and
`starfleet.crt` in your current folder:

```sh
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout starfleet.key -out starfleet.crt \
  -subj "/CN=starfleet.example.com/O=starfleet"
kubectl create secret tls starfleet-credential -n istio-ingress \
  --key=starfleet.key --cert=starfleet.crt
```

```text
.+......+.........+.........+++++++++++++++++++++++++++++++++++++++*.+...+....
...........+..............+.+++++++++++++++++++++++++++++++++++++++*..........
-----
secret/starfleet-credential created
```

We shortened the two lines of dots and plus signs: `openssl` prints them while it makes the key.

The secret goes to `istio-ingress`, the planet where the gateway pod runs. The
gateway can only read secrets from its own namespace.

Save this as `gateway-starfleet.yaml`:

```yaml
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
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - starfleet.example.com
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: starfleet-credential
    hosts:
    - starfleet.example.com
```

Save this as `authorizationpolicy-gateway-ip-deny.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: gateway-ip-deny
  namespace: istio-ingress
spec:
  selector:
    matchLabels:
      istio: ingress
  action: DENY
  rules:
  - from:
    - source:
        remoteIpBlocks: ["192.168.0.0/16"]
```

Apply both:

```sh
kubectl apply -f gateway-starfleet.yaml
kubectl apply -f authorizationpolicy-gateway-ip-deny.yaml
```

Wait about a minute, so the gate opens the new door and gets the policy. Then check the result. `--resolve` sends `starfleet.example.com` to
`127.0.0.1`, so the TLS name matches, and `-k` accepts the self-signed
certificate:

```sh
gate_status /productpage 192.168.5.5
curl -sk -o /dev/null -w "%{http_code}\n" --resolve starfleet.example.com:8443:127.0.0.1 \
  -H "X-Forwarded-For: 192.168.5.5" https://starfleet.example.com:8443/productpage
curl -sk -o /dev/null -w "%{http_code}\n" --resolve starfleet.example.com:8443:127.0.0.1 \
  -H "X-Forwarded-For: 10.1.2.3" https://starfleet.example.com:8443/productpage
```

```text
403
403
200
```

The policy selects the gateway **pod**, not one of its listeners, so it
guards every port the gate opens.

</details>
