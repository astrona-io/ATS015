# Solution Walkthrough

The `Gateway` and the `VirtualService` were right all along. The gateway's secret held the other CA as `ca.crt`, so the gateway checked every client certificate against the wrong CA: the partner's certificate failed the check, and the stranger's passed.

---

## Step 1: Confirm the failure

Start the port forward, then send a request with the partner's certificate and one with the stranger's certificate. The `knock` helper sends one HTTPS request and prints the status code and curl's exit code:

```sh
kubectl -n istio-ingress port-forward svc/istio-ingress 8443:443 >/dev/null 2>&1 &
cd /tmp/ats-015-lab-040-02-02
knock() { curl -s -o /dev/null -w "%{http_code} " --cacert example.com.crt \
  --resolve starfleet.example.com:8443:127.0.0.1 "$@" https://starfleet.example.com:8443/productpage; echo "exit=$?"; }
knock --cert partner.crt --key partner.key
knock --cert stranger.crt --key stranger.key
```

```text
000 exit=56
200 exit=0
```

The partner is refused in the handshake (`000`, curl exit code `56`), and the stranger reaches the `bridge`. The gateway does ask for a client certificate, so `MUTUAL` is on. It just trusts the wrong CA. In our run, `kubectl port-forward` survived the refused handshake. If a later `knock` prints `exit=7`, the port forward ended: start it again.

## Step 2: Find out which CA the gateway trusts

Read the CA out of the gateway's secret and print its subject:

```sh
kubectl get secret starfleet-credential-mutual -n istio-ingress \
  -o jsonpath='{.data.ca\.crt}' | base64 -d | openssl x509 -noout -subject
```

```text
subject=O=Other Inc., CN=other-ca
```

The gateway checks clients against `other-ca`, the stranger's CA. The partner's certificate was signed by `example.com`, so it fails the check.

The gateway's proxy shows the same thing from its side. It holds the CA under the secret's name plus `-cacert`:

```sh
istioctl proxy-config secret deploy/istio-ingress -n istio-ingress
```

```text
RESOURCE NAME                                       TYPE           STATUS     VALID CERT     SERIAL NUMBER                               NOT AFTER                NOT BEFORE
kubernetes://starfleet-credential-mutual            Cert Chain     ACTIVE     true           00000000000000000000000000000000            2027-10-09T10:19:12Z     2026-10-09T10:19:12Z
default                                             Cert Chain     ACTIVE     true           bb77d763f04e0fdc361a3a9e60267147            2026-10-10T10:18:32Z     2026-10-09T10:16:32Z
kubernetes://starfleet-credential-mutual-cacert     CA             ACTIVE     true           f54f54bba30b83c7016973f9ab7c2281e92508d     2027-10-09T10:19:12Z     2026-10-09T10:19:12Z
ROOTCA                                              CA             ACTIVE     true           cfb3260f9b0d93d1d27cc099cdf2a016            2036-10-06T10:18:22Z     2026-10-09T10:18:22Z
```

Note the serial number of the `-cacert` row, `f54f54bb...`. It belongs to `other-ca`. Your certificates and serial numbers differ, because the bootstrap makes new ones on every run.

Both rows are `ACTIVE`, so the gateway loaded the secret without trouble. Nothing is broken in the delivery: the content is wrong.

## Step 3: Put the right CA in the secret

Keep the server certificate and key, and replace `ca.crt` with your CA, `example.com.crt`. `kubectl create` with `--dry-run=client -o yaml`, piped into `kubectl apply`, replaces the existing secret in one step:

```sh
kubectl create -n istio-ingress secret generic starfleet-credential-mutual \
  --from-file=tls.key=starfleet.example.com.key \
  --from-file=tls.crt=starfleet.example.com.crt \
  --from-file=ca.crt=example.com.crt \
  --dry-run=client -o yaml | kubectl apply -f -
```

```text
secret/starfleet-credential-mutual configured
```

There is no warning about a missing `last-applied-configuration` here, because the bootstrap also created this secret with `kubectl apply`.

No restart is needed. `istiod`, Istio's control plane, sees the changed secret and sends the new CA to the gateway's proxy by itself. Give it about a minute before you test: for a few seconds the gateway can still hold the old CA.

## Step 4: Prove it works

The `-cacert` row is still `ACTIVE`, now with your CA (its serial number changed):

```sh
istioctl proxy-config secret deploy/istio-ingress -n istio-ingress | grep cacert
```

```text
kubernetes://starfleet-credential-mutual-cacert     CA             ACTIVE     true           1298836eff8172d2ca8751b6898578a84d657c22     2027-10-09T10:19:12Z     2026-10-09T10:19:12Z
```

Then send three requests: with the partner's certificate, with no certificate, and with the stranger's certificate:

```sh
knock --cert partner.crt --key partner.key
knock
knock --cert stranger.crt --key stranger.key
```

```text
200 exit=0
000 exit=56
000 exit=56
```

The partner reaches the `bridge`. A client without a certificate and the stranger are both refused in the handshake.

Now submit:

```sh
astrona submit -c sections/section-040/module-02/labs/lab-02
```

---

## Common Mistakes

- **Switching the `Gateway` to `SIMPLE`.** The partner gets in, but so does everyone else. The `Gateway` was correct, and the grader checks that it is unchanged and still `MUTUAL`.
- **Adding your CA next to the stranger's CA.** A `ca.crt` with both CAs lets the partner in, but the stranger too. The grader checks that `other-ca` is gone.
- **Replacing `tls.crt` with the CA.** `tls.crt` is the gateway's own server certificate, and `ca.crt` is the CA it checks clients against. Mixing them up breaks the handshake for everyone.
- **Creating the new secret in `starfleet`.** The gateway reads `credentialName` from its own namespace, `istio-ingress`.
- **Reading the client's error to find the cause.** No certificate and a certificate from the wrong CA look the same from outside. Read the secret and the gateway's proxy.
