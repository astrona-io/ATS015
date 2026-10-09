# Solution Walkthrough

Mission debrief, astronaut. The certificate was fine all along. It sat in a Secret on the wrong planet, so the gateway never received it, and the `Gateway` served a host name nobody asks for. You find each fault from its clue, fix it, and prove the bridge answers over HTTPS.

---

## Step 1: Confirm the failure

Get the CA onto your machine, then send one HTTPS signal:

```sh
kubectl get configmap starfleet-ca -n starfleet -o jsonpath='{.data.ca\.crt}' > starfleet-ca.crt
curl -s -o /dev/null -w "%{http_code} " --cacert starfleet-ca.crt \
  --resolve starfleet.example.com:8443:127.0.0.1 https://starfleet.example.com:8443/productpage; echo "exit=$?"
```

```text
000 exit=35
```

`000` means no HTTP was spoken. Exit code `35` says the gate cut the handshake, so the problem is at the gate: its certificate, or the host names it serves. The exit code cannot tell you which, so ask the gateway next.

After a failed handshake the port forward on `8443` restarts itself. If you send another signal within a few seconds and get `000 exit=7`, wait ten seconds and try again.

## Step 2: Ask the gateway what it holds

```sh
istioctl proxy-config secret deploy/istio-ingress -n istio-ingress
```

```text
RESOURCE NAME                         TYPE           STATUS      VALID CERT     SERIAL NUMBER                        NOT AFTER                NOT BEFORE
kubernetes://starfleet-credential                    WARMING     false
default                               Cert Chain     ACTIVE      true           e479e358fc4945791813138f3226cfbd     2026-10-10T09:47:22Z     2026-10-09T09:45:22Z
ROOTCA                                CA             ACTIVE      true           b1d06e4db800e288741a04f2e152179d     2036-10-06T09:47:10Z     2026-10-09T09:47:10Z
```

The gateway asked for `starfleet-credential`, but the row is `WARMING`: it is waiting for a Secret that never arrives. `istiod` looks for it in `istio-ingress`, the gateway pod's namespace.

## Step 3: Let `istioctl analyze` name the problems

```sh
istioctl analyze -n starfleet
```

```text
Error [IST0101] (Gateway starfleet/starfleet-gateway) Referenced credentialName not found: "starfleet-credential"
Warning [IST0132] (VirtualService starfleet/bridge) one or more host [starfleet.example.com] defined in VirtualService starfleet/bridge not found in Gateway starfleet/starfleet-gateway.
Error: Analyzers found issues when analyzing namespace: starfleet.
See https://istio.io/v1.30/docs/reference/config/analysis for more information about causes and resolutions.
```

`IST0101` says the `Gateway`'s `credentialName` does not resolve. `IST0132` says the flight plan asks for `starfleet.example.com`, but the `Gateway` does not serve that host. Now look at where the Secret really is, and at the host the `Gateway` serves:

```sh
kubectl get secret -A --field-selector metadata.name=starfleet-credential
kubectl get gateway.networking.istio.io starfleet-gateway -n starfleet -o jsonpath='{.spec.servers[0].hosts}{"\n"}'
```

```text
NAMESPACE   NAME                   TYPE                DATA   AGE
starfleet   starfleet-credential   kubernetes.io/tls   2      29s
["bridge.example.com"]
```

Two faults: the Secret is in `starfleet`, and the door serves `bridge.example.com` instead of `starfleet.example.com`.

---

## Step 4: Put the Secret where the gateway reads it

Copy the certificate and key out of the Secret in `starfleet`:

```sh
kubectl get secret starfleet-credential -n starfleet -o jsonpath='{.data.tls\.crt}' | base64 -d > tls.crt
kubectl get secret starfleet-credential -n starfleet -o jsonpath='{.data.tls\.key}' | base64 -d > tls.key
```

Then create the Secret in `istio-ingress`:

```sh
kubectl create secret tls starfleet-credential -n istio-ingress --cert=tls.crt --key=tls.key
```

```text
secret/starfleet-credential created
```

Do not move the `Gateway` instead: the Secret lookup always uses the gateway pod's namespace, wherever the `Gateway` lives. The old Secret in `starfleet` does no harm; you can delete it with `kubectl delete secret starfleet-credential -n starfleet`.

## Step 5: Serve the right host

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
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - starfleet.example.com
    tls:
      mode: SIMPLE
      credentialName: starfleet-credential
```

Apply it:

```sh
kubectl apply -f gateway-starfleet.yaml
```

```text
gateway.networking.istio.io/starfleet-gateway configured
```

---

## Step 6: Prove it

Wait about thirty seconds, so `istiod` can push the new certificate and door to the gateway. Then check the gateway first, and send a signal:

```sh
istioctl proxy-config secret deploy/istio-ingress -n istio-ingress | grep starfleet-credential
istioctl analyze -n starfleet
curl -s -o /dev/null -w "%{http_code} " --cacert starfleet-ca.crt \
  --resolve starfleet.example.com:8443:127.0.0.1 https://starfleet.example.com:8443/productpage; echo "exit=$?"
```

```text
kubernetes://starfleet-credential     Cert Chain     ACTIVE     true           00000000000000000000000000000001     2027-10-09T09:48:03Z     2026-10-09T09:48:03Z

✔ No validation issues found when analyzing namespace: starfleet.
200 exit=0
```

`ACTIVE` means the gateway holds the certificate. `200 exit=0` means curl trusted it with only the lab CA, the name matched, and the bridge answered. If you still see `WARMING` or an old exit code, wait half a minute and run the commands again.

## Step 7: Submit

```sh
astrona submit -c sections/section-040/module-01/labs/lab-02
```

---

## Common mistakes

- **Fixing only one fault.** Either fault alone still makes the handshake fail with exit `35`. With the Secret still in `starfleet`, `proxy-config secret` keeps showing `WARMING` and `analyze` keeps reporting `IST0101`; with the wrong host still on the `Gateway`, `analyze` keeps reporting `IST0132`.
- **Testing with `-k`.** It hides trust problems. Use `--cacert starfleet-ca.crt`; the grader does too.
- **Making a new certificate.** The grader checks that the Secret holds a certificate signed by the lab CA. Copy the existing one instead.
- **Writing `starfleet/starfleet-credential` in `credentialName`.** Use the bare name, and put the Secret in `istio-ingress`.
