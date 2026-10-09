# When The Handshake Fails

Astronaut, most TLS mistakes at the gate give you no error message. Kubernetes accepts every object, and then the handshake simply fails, with no HTTP status to read. In this part you make the two most common mistakes on purpose, read the clues they leave, and learn to name the cause from curl's exit code.

## A Secret on the wrong planet

The most common exam mistake is a Secret created next to the `Gateway`, in the app's namespace, instead of in the gateway pod's namespace. Make it once on purpose, so you recognise every clue when it happens by accident.

<!-- astrona:playground:renew -->

### Make the mistake

Create a second Secret with the same certificate, but on the planet `starfleet`, where the `Gateway` lives:

```sh
kubectl create -n starfleet secret tls starfleet-credential-app-ns \
  --key=certs/starfleet.example.com.key --cert=certs/starfleet.example.com.crt
```

```text
secret/starfleet-credential-app-ns created
```

Now point the `Gateway` at it. Save this as `gateway-starfleet-wrong-namespace.yaml`:

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
      credentialName: starfleet-credential-app-ns
```

Apply it:

```sh
kubectl apply -f gateway-starfleet-wrong-namespace.yaml
```

```text
gateway.networking.istio.io/starfleet-gateway configured
```

Kubernetes accepts it. It does not check that the named Secret exists, or where.

### Read the failure

Wait about a minute, then send a signal:

```sh
https_status
```

```text
000 exit=35
```

`000` means there is no HTTP status at all, because no HTTP was ever spoken. Exit code `35` means the TLS handshake failed: the gate had no certificate to show for this door, so it cut the connection.

Why wait? For the first few seconds the gate keeps its old door open, with the old certificate, while it waits for the new one. In our run, a signal sent ten seconds after the apply still got `200`. Only when the new certificate never comes does the gate switch to the new door, and every handshake fails.

After a failed handshake, the port forward on `8443` also drops and restarts itself. For a few seconds the next signal gets `000 exit=7`. Wait about ten seconds between tries in this part.

### Ask the gateway

Look at the certificates the gateway's Envoy holds:

```sh
istioctl proxy-config secret deploy/istio-ingress -n istio-ingress
```

```text
RESOURCE NAME                                TYPE           STATUS      VALID CERT     SERIAL NUMBER                        NOT AFTER                NOT BEFORE
kubernetes://starfleet-credential-app-ns                    WARMING     false
kubernetes://starfleet-credential            Cert Chain     ACTIVE      true           00000000000000000000000000000002     2027-10-09T09:27:39Z     2026-10-09T09:27:39Z
default                                      Cert Chain     ACTIVE      true           cd9f733cc187f798b625d29f662422ef     2026-10-10T09:25:24Z     2026-10-09T09:23:24Z
ROOTCA                                       CA             ACTIVE      true           b6675b08fb0a7611a0824cb0029d824d     2036-10-06T09:25:12Z     2026-10-09T09:25:12Z
```

The Envoy knows the name `starfleet-credential-app-ns`, because the `Gateway` asked for it. But the state is **`WARMING`**, with no certificate: it is waiting for a Secret that never comes. `istiod` looked in `istio-ingress`, found nothing, and had nothing to send. The old `starfleet-credential` is still listed as `ACTIVE`, but no door uses it any more.

### Ask `istioctl analyze`

`istioctl analyze` checks objects against each other, so it can spot a `credentialName` with no Secret behind it:

```sh
istioctl analyze -n starfleet
```

```text
Error [IST0101] (Gateway starfleet/starfleet-gateway) Referenced credentialName not found: "starfleet-credential-app-ns"
Error: Analyzers found issues when analyzing namespace: starfleet.
See https://istio.io/v1.30/docs/reference/config/analysis for more information about causes and resolutions.
```

**`IST0101`** ("referenced resource not found") names the `Gateway` and the missing credential. The Secret does exist, but not where the gateway can see it.

### Put it back

Apply your correct file again. It points at `starfleet-credential` in `istio-ingress`, and it brings back the redirect door:

```sh
kubectl apply -f gateway-starfleet.yaml
```

```text
gateway.networking.istio.io/starfleet-gateway configured
```

Then wait about fifteen seconds and check the result:

```sh
https_status
```

```text
200 exit=0
```

The fix for this mistake is always the same: create the Secret in the gateway pod's namespace. Copying the `Gateway` to `istio-ingress` does not help, because the Secret lookup ignores where the `Gateway` lives.

## A host the gate does not serve

The second common mistake is a name mismatch. The gate picks a door by the SNI host name in the handshake. A name that no door lists has no certificate, so the handshake fails before any HTTP exists.

### Ask for another host

Send a signal for `other.example.com`. Add `-k`, so curl skips its own trust check and only the gate can say no:

```sh
curl -s -o /dev/null -w "%{http_code} " -k --resolve other.example.com:8443:127.0.0.1 \
  https://other.example.com:8443/productpage; echo "exit=$?"
```

```text
000 exit=35
```

Exit code `35` again: the handshake itself failed. Even `-k` does not help: the gate has no door for `other.example.com`, so it has no certificate to show. That is why you will never see a `404` for a wrong host on an HTTPS door. A `404` comes later, from the route table, once the seal is open.

The same failure hits you when you test with `https://127.0.0.1:8443` instead of the host name. curl then sends no usable SNI, and no door matches. Always test with `--resolve` and the exact host from the `Gateway`'s `hosts`.

## What the exit codes tell you

When TLS fails, curl prints `000` as the status. The exit code is the real clue: it tells you which side to look at next, even when it cannot name the exact cause.

### The codes you will meet

| curl exit code | What it means | Look at |
| --- | --- | --- |
| `0` | ok | nothing |
| `7` | cannot connect at all | the port forward (it also restarts for a few seconds after a failed handshake), the gateway Service |
| `35` | the gate cut the handshake | `proxy-config secret` first, then SNI against the `Gateway` `hosts` |
| `60` | the certificate is not trusted | the client: `--cacert`, or a certificate from another CA |

Notice that both mistakes in this part gave the same `35`: the Secret on the wrong planet and the host the gate does not serve. We saw the same code from curl on a Mac and from the Linux curl in the `shuttle`. Some curl builds report a cut handshake as `56` instead, so treat `35` and `56` alike. The exit code tells you "the gate said no during the handshake"; the next step tells you why.

### A short checklist

```mermaid
flowchart TB
    A["https_status"] -->|"exit=7"| P["port forward"]
    A -->|"exit=60"| T["client trust"]
    A -->|"exit=35"| S["proxy-config secret"]
    S -->|"missing or WARMING"| N["Secret namespace and keys"]
    S -->|"ACTIVE"| H["SNI and Gateway hosts"]
    A -->|"404"| V["VirtualService"]
```

Start from the exit code, then let `istioctl proxy-config secret` on the gateway split "the certificate never arrived" from "the certificate is there but the name does not match".

Two `tls` settings fail in the same way: `minProtocolVersion` (for example `TLSV1_3`) and `cipherSuites`. A client that is too old, or shares no cipher with the gate, fails during the handshake with no HTTP status. For example, with `minProtocolVersion: TLSV1_3` on the door, `https_status --tls-max 1.2` gets `000 exit=35`. If the Secret is `ACTIVE` and the name matches, check these next.

> [!TIP]
> In an exam task, read curl's exit code before you change any YAML, and on a `35` run `istioctl proxy-config secret` on the gateway next. Together they point at the right object, so you do not edit the wrong one.

## Common pitfalls

> [!WARNING]
> - **Looking for an HTTP status when TLS fails.** There is none. `000` is curl's way of saying "no HTTP happened"; read the exit code.
> - **Moving the `Gateway` instead of the Secret.** The lookup always uses the gateway pod's namespace. Move or recreate the Secret.
> - **Trusting `kubectl get` alone.** The `Gateway` and the Secret both exist, and it still fails. `istioctl proxy-config secret` shows whether the gate really has the certificate.
> - **Testing with an IP address.** No SNI, no door, exit `35`.
> - **Testing again too fast.** After a failed handshake the port forward restarts, and the next signal gets `exit=7` for a few seconds. Wait ten seconds before you read that as a new problem.

> *Both a missing certificate and a wrong host name fail the handshake with exit code 35; `WARMING` in the gate and `IST0101` in `analyze` tell you it is the certificate.*

## Your mission: Repair The Gate's Certificate

You can now read a failed handshake, find a Secret on the wrong planet, and spot a host name the gate does not serve. Now prove it in a graded mission: the HTTPS door to the bridge is broken in two places, and you must make `https://starfleet.example.com` answer again with the right certificate.

The mission runs in its own training solar system, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-015-playground-040-01
```

Then start the mission:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-01/labs/lab-02
```

Read the task in [`question.md`](./labs/lab-02/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-040/module-01/labs/lab-02
```

When the mission is done, remove it and wake your playground up again:

```sh
astrona destroy ats-015-lab-040-01-02
astrona start ats-015-playground-040-01
```
