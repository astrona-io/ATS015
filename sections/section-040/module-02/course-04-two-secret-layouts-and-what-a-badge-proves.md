# Two Secret Layouts And What A Badge Proves

Astronaut, so far the gate's badge and the CA lived in one secret. Istio also accepts a second layout, with the CA in a secret of its own. You will meet both in real clusters and in exam tasks, so in this part you switch the gate to the second layout and watch it keep working.

Then you step back and ask what the badge check has really achieved. It tells the gate that a CA it trusts signed the visitor's badge. It does not tell the gate what that visitor may do.

The commands below need the `VirtualService` `bridge` and the `Gateway` `starfleet-gateway` in your playground, the files in `certs/`, and the `https_status` helper from the landing page.

## The split layout: a separate `-cacert` secret

In the split layout, `credentialName` names a normal TLS secret with only `tls.crt` and `tls.key`. The gate then looks for the CA in a second secret with the **same name plus `-cacert`**, under the key `ca.crt`.

| Layout | Secret named in `credentialName` | Second secret |
| --- | --- | --- |
| One secret | `tls.crt`, `tls.key`, `ca.crt` | none |
| Split | `tls.crt`, `tls.key` | `<credentialName>-cacert` with `ca.crt` |

The split layout is handy when one team owns the server badge and another team owns the list of trusted CAs. It also lets you build the server secret with `kubectl create secret tls`. Both secrets still live on the gate's planet, `istio-ingress`.

<!-- astrona:playground:renew -->

### Create the two secrets

Create the server secret and its `-cacert` partner:

```sh
kubectl create -n istio-ingress secret tls starfleet-credential-split \
  --key=certs/starfleet.example.com.key --cert=certs/starfleet.example.com.crt
kubectl create -n istio-ingress secret generic starfleet-credential-split-cacert \
  --from-file=ca.crt=certs/example.com.crt
```

```text
secret/starfleet-credential-split created
secret/starfleet-credential-split-cacert created
```

The first secret has the type `kubernetes.io/tls`, the type `kubectl create secret tls` always makes. The second is a generic secret that holds only the CA.

### Point the gate at the split secret

Change only `credentialName`. Save this as `gateway-starfleet.yaml`, replacing the earlier version:

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
      mode: MUTUAL
      credentialName: starfleet-credential-split
```

Apply it:

```sh
kubectl apply -f gateway-starfleet.yaml
```

```text
gateway.networking.istio.io/starfleet-gateway configured
```

Then check the result. Wait about a minute for the new orders to reach the gate. Knock with the trusted badge, without a badge and with the stranger's badge (with a pause for the port forward after the refused knock), and list the gate's certificates:

```sh
https_status --cert certs/client.example.com.crt --key certs/client.example.com.key
https_status
sleep 10
https_status --cert certs/other-client.crt --key certs/other-client.key
istioctl proxy-config secret deploy/istio-ingress -n istio-ingress | grep split
```

```text
200 exit=0
000 exit=56
000 exit=56
kubernetes://starfleet-credential-split            Cert Chain     ACTIVE     true           00000000000000000000000000000000            2027-10-09T09:54:16Z     2026-10-09T09:54:16Z
kubernetes://starfleet-credential-split-cacert     CA             ACTIVE     true           3d422aafaca8b249728daca5d34e0ce4ec6c9ae     2027-10-09T09:54:16Z     2026-10-09T09:54:16Z
```

The gate behaves exactly as before. The proxy holds the same two items: the server badge, and the CA under the `-cacert` name. This time the `-cacert` item really comes from a secret with that name.

The stranger's badge needs the `certs/other-client.*` files. If you have not made them yet, the third line fails with a curl file error instead.

## What a checked badge proves

A checked badge answers one question: *did a CA I trust sign this?* If your CA signs badges for five partners, all five get in. The gate has no further opinion about which partner is calling, or what each one may do.

### Who is this visitor?

Telling the partners apart is a separate step, and there are two places to do it:

- **In the app.** The gateway can pass the badge's details on to the app in a header called `X-Forwarded-Client-Cert` (XFCC). It carries fields such as the badge's subject and its SAN. An app that needs to treat partners differently reads that header. The header is only trustworthy because the gate sets it after the check. An app that can also be reached some other way must not believe it.
- **At the gate.** An `AuthorizationPolicy` that selects the gateway pods can allow or deny signals after the badge check, for example by source address or by path.

Either way the rule is the same: **authentication says who, authorization decides what.** `MUTUAL` TLS only does the first. It does it at the earliest moment possible, which is its real value: a visitor without a trusted badge never gets to send a request.

### Badges and tokens answer different questions

A JSON Web Token (JWT) identifies an end user, a person, and can carry roles. A client badge identifies a calling **system** and carries little more than a name. An API that serves partner systems on behalf of their users often wants both.

### The edge and the mesh are separate

Badges at the gate and the mesh's secret handshake (mTLS between sidecars) look alike, but they share no machinery:

| | Mesh mTLS (the secret handshake) | `MUTUAL` at the gate |
| --- | --- | --- |
| Who issues the certificates | `istiod`, automatically | your own CA |
| Who renews them | `istiod`, automatically | you |
| What the identity is used for | `principals` in authorization rules | up to you |

Turning one on says nothing about the other. A gate can demand badges while the mesh behind it is fully `PERMISSIVE`, and the other way round. Check `PeerAuthentication` separately.

## Common pitfalls

> [!WARNING]
> - **Getting the `-cacert` name wrong.** The second secret must be called exactly `<credentialName>-cacert`, with the key `ca.crt`, on the planet `istio-ingress`. Any other name and the gate has no CA.
> - **Treating a checked badge as permission.** It proves that your CA signed the badge, and nothing more. Decide what each partner may do in the app or with an `AuthorizationPolicy`.
> - **Trusting `X-Forwarded-Client-Cert` everywhere.** Only the gate sets it after a real check. A backend that can be reached around the gate must not believe it.
> - **Assuming a `MUTUAL` gate means mesh mTLS.** They are unrelated. Check `PeerAuthentication` on its own.

> *A badge check tells the gate who signed for the visitor; deciding what that visitor may do is a separate job.*
