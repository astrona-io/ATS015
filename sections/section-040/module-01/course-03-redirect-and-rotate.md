# Redirect And Rotate

Astronaut, your HTTPS door works. Two jobs follow every working TLS door. Callers who still knock on the plain HTTP door must be sent to the sealed one. And one day the certificate must be replaced, without closing the gate. In this part you do both.

## Send plain HTTP to HTTPS

Serving HTTPS does not stop anyone from calling port `80`. You want those callers told "use the HTTPS address instead", and served nothing in plain text. A second server in the same `Gateway` does that.

<!-- astrona:playground:renew -->

### Knock on the plain door first

Send a plain HTTP signal to the gateway's port `80`, through the port forward on `8080`:

```sh
curl -s -o /dev/null -w "%{http_code}\n" --resolve starfleet.example.com:8080:127.0.0.1 \
  http://starfleet.example.com:8080/productpage; echo "exit=$?"
```

```text
000
exit=52
```

No answer at all: exit code `52` means curl got an empty reply. Your `Gateway` has no server on port `80`, so the gateway has nothing listening there, and the port forward closes the connection. The port forward then restarts on its own, which takes a few seconds.

### Add the redirect door

Open `gateway-starfleet.yaml` and add a second server for port `80`. The whole file now looks like this:

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
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - starfleet.example.com
    tls:
      mode: SIMPLE
      credentialName: starfleet-credential
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - starfleet.example.com
    tls:
      httpsRedirect: true
```

Apply it:

```sh
kubectl apply -f gateway-starfleet.yaml
```

```text
gateway.networking.istio.io/starfleet-gateway configured
```

### Then check the result

Wait about ten seconds, so the gate gets its new orders and the port forward is back. Then knock on the plain door again, and print where the answer sends you:

```sh
curl -s -o /dev/null -w "%{http_code} -> %{redirect_url}\n" --resolve starfleet.example.com:8080:127.0.0.1 \
  http://starfleet.example.com:8080/productpage
```

```text
301 -> https://starfleet.example.com:8080/productpage
```

The gateway answers `301` ("moved permanently") and points at the same address with `https://`. It keeps the port you used, here the local `8080`. Behind a real load balancer, clients call port `80`, and the redirect sends them to the normal HTTPS port.

### Why a `tls` block on an HTTP port

A `tls` block on port `80` looks wrong at first: there is no TLS there. Read it as "how this door relates to TLS". With `httpsRedirect: true`, the answer is "always send callers to TLS". The gateway answers every request on that door with a redirect, and no request reaches the bridge.

That is right for browsers, which follow redirects on their own. A machine client that does not follow redirects only sees a `301` with no page. So think twice before you put a redirect in front of an API that other programs call.

## Replace a certificate without a restart

Certificates expire. A public certificate often lives only 90 days, so you replace it often. Because the gate gets its certificate from `istiod` over SDS, replacing the Secret is all it takes. The gateway does not restart and keeps its open connections.

### Make a new certificate

Make a second server certificate for the same host, with a different organisation name so you can tell the two apart:

```sh
openssl req -newkey rsa:2048 -nodes -keyout certs/starfleet-v2.key \
  -subj '/O=Starfleet Fleet Two/CN=starfleet.example.com' -out certs/starfleet-v2.csr
openssl x509 -req -sha256 -days 365 -CA certs/starfleet-ca.crt -CAkey certs/starfleet-ca.key \
  -set_serial 2 -in certs/starfleet-v2.csr -out certs/starfleet-v2.crt -extfile certs/san.ext
```

After the progress dots for the new key, `openssl` prints:

```text
Certificate request self-signature ok
subject=O=Starfleet Fleet Two, CN=starfleet.example.com
```

### Update the Secret in place

`kubectl create secret` refuses a name that already exists. So let it write the new Secret as YAML, and hand that to `kubectl apply`, which updates the existing one:

```sh
kubectl create -n istio-ingress secret tls starfleet-credential \
  --key=certs/starfleet-v2.key --cert=certs/starfleet-v2.crt \
  --dry-run=client -o yaml | kubectl apply -f -
```

```text
Warning: resource secrets/starfleet-credential is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by kubectl apply. kubectl apply should only be used on resources created declaratively by either kubectl create --save-config or kubectl apply. The missing annotation will be patched automatically.
secret/starfleet-credential configured
```

The warning is harmless. You first made this Secret with `kubectl create`, so it lacks a note that `kubectl apply` keeps on the objects it manages. `kubectl apply` adds the note and updates the Secret.

### Then check the result

Ask the gate which certificate it shows now:

```sh
https_status -v 2>&1 | grep -E "subject:|exit="
```

```text
*  subject: O=Starfleet Fleet Two; CN=starfleet.example.com
200 exit=0
```

The subject now names `Starfleet Fleet Two`. You changed one Secret, and `istiod` pushed the new certificate to the running gateway. You did not touch the `Gateway`, and you did not restart a pod. If the old subject (`O=Starfleet`) still shows, wait ten seconds and run it again: in our run, the first try right after the apply still got the old certificate.

> [!TIP]
> In real clusters a tool such as `cert-manager` usually renews the Secret for you. The gateway picks up each renewal the same way, so your job is only to make sure the Secret has the right name and lives in the gateway's namespace.

## Common pitfalls

> [!WARNING]
> - **A redirect door with no `hosts`.** Every server needs `hosts`; the redirect door must list the same host names as the HTTPS door.
> - **Putting `credentialName` on the port 80 door.** The redirect door needs no certificate. Only `httpsRedirect: true` belongs in its `tls` block.
> - **A redirect in front of API clients.** A program that does not follow redirects sees only a `301`.
> - **Deleting the Secret to replace it.** Between delete and create, the gate has no certificate and new handshakes fail. Update it in place with `apply`.

> *`httpsRedirect` turns port 80 into a signpost to HTTPS, and replacing the Secret rotates the certificate on a running gate.*

## Your mission: Serve HTTPS At The Ingress Gateway

You can now put a certificate where the gateway reads it, open an HTTPS door, and redirect plain HTTP. Now prove it in a graded mission: expose a booking service over HTTPS from certificate files you are handed, with plain HTTP redirected. This mission still runs an older small app (`booking-service` in the namespace `tls-demo`), with the gateway that `istioctl install` creates in `istio-system`, so its names differ from the Starfleet.

The mission runs in its own training solar system, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-015-playground-040-01
```

Then start the mission:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-01/labs/lab-01
```

Read the task in [`question.md`](./labs/lab-01/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-040/module-01/labs/lab-01
```

When the mission is done, remove it and wake your playground up again:

```sh
astrona destroy ats-015-lab-040-01
astrona start ats-015-playground-040-01
```
