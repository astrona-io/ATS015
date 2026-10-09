# The Separate CA Secret And What A Client Certificate Proves

A `MUTUAL` gateway can read the server certificate and the CA from one secret. Istio also accepts a second layout, with the CA in a secret of its own. You will meet both in real clusters and in exam tasks, so in this part you switch the gateway to the second layout and watch it keep working.

Then you look at what the client certificate check has really achieved. It tells the gateway that a CA it trusts signed the client's certificate. It does not tell the gateway what that client may do.

The commands below need the `VirtualService` `bridge` and the `Gateway` `starfleet-gateway` in your playground, the files in `certs/`, and the `https_status` helper from the landing page.

## The split layout: a separate `-cacert` secret

In the split layout, `credentialName` names a normal TLS secret with only `tls.crt` and `tls.key`. The gateway then looks for the CA in a second secret with the **same name plus `-cacert`**, under the key `ca.crt`.

| Layout | Secret named in `credentialName` | Second secret |
| --- | --- | --- |
| One secret | `tls.crt`, `tls.key`, `ca.crt` | none |
| Split | `tls.crt`, `tls.key` | `<credentialName>-cacert` with `ca.crt` |

The split layout is handy when one team owns the server certificate and another team owns the list of trusted CAs. It also lets you build the server secret with `kubectl create secret tls`. Both secrets still live in the gateway pod's namespace, `istio-ingress`.

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

### Point the gateway at the split secret

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

Then check the result. Wait about a minute for `istiod`, Istio's control plane, to push the new configuration to the gateway. Send a request with the trusted client certificate, one without a certificate and one with the untrusted certificate (with a pause for the port forward after the refused handshake), and list the gateway's certificates:

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

The gateway behaves exactly as before. The proxy holds the same two items: the server certificate, and the CA under the `-cacert` name. This time the `-cacert` item really comes from a secret with that name.

The untrusted client certificate needs the `certs/other-client.*` files. If you have not made them yet, the third line fails with a curl file error instead.

## What a checked client certificate proves

A checked client certificate answers one question: *did a CA I trust sign this?* If your CA signs certificates for five partners, all five can connect. The gateway does not decide which partner is calling, or what each one may do.

### Who is this client?

Telling the partners apart is a separate step, and there are two places to do it:

- **In the app.** The gateway can pass the certificate's details on to the app in a header called `X-Forwarded-Client-Cert` (XFCC). It carries fields such as the certificate's subject and its SAN. An app that needs to treat partners differently reads that header. The header is only trustworthy because the gateway sets it after the check. An app that can also be reached some other way must not believe it.
- **At the gateway.** An `AuthorizationPolicy` (a policy that allows or denies requests to a workload) that selects the gateway pods can allow or deny requests after the certificate check, for example by source address or by path.

Either way the rule is the same: **authentication says who, authorization decides what.** `MUTUAL` TLS only does the first. It does it at the earliest moment possible, which is its real value: a client without a trusted certificate never gets to send a request.

### Client certificates and tokens answer different questions

A JSON Web Token (JWT) identifies an end user, a person, and can carry roles. A client certificate identifies a calling **system** and carries little more than a name. An API that serves partner systems on behalf of their users often wants both.

### The edge and the mesh are separate

Client certificates at the gateway and mesh mTLS (mutual TLS between sidecar proxies, where both sides present a certificate) look alike, but they share no machinery:

| | Mesh mTLS | `MUTUAL` at the gateway |
| --- | --- | --- |
| Who issues the certificates | `istiod`, automatically | your own CA |
| Who renews them | `istiod`, automatically | you |
| What the identity is used for | `principals` in authorization rules | up to you |

Turning one on says nothing about the other. A gateway can require client certificates while the mesh behind it is fully `PERMISSIVE`, and the other way round. Check `PeerAuthentication` (the resource that sets whether workloads accept plain text, mTLS or both) separately.

## Common pitfalls

> [!WARNING]
> - **Getting the `-cacert` name wrong.** The second secret must be called exactly `<credentialName>-cacert`, with the key `ca.crt`, in the namespace `istio-ingress`. Any other name and the gateway has no CA.
> - **Treating a checked client certificate as permission.** It proves that your CA signed the certificate, and nothing more. Decide what each partner may do in the app or with an `AuthorizationPolicy`.
> - **Trusting `X-Forwarded-Client-Cert` everywhere.** Only the gateway sets it after a real check. A backend that can be reached without going through the gateway must not believe it.
> - **Assuming a `MUTUAL` gateway means mesh mTLS.** They are unrelated. Check `PeerAuthentication` on its own.

> *A client certificate check tells the gateway who signed for the client; deciding what that client may do is a separate job.*
