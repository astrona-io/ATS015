# Part 1 — Building the PKI

> Prerequisite: [the module landing page](./course.md). Next: [Part 2 — The credential secret and the validation context](./course-02-secret-and-validation-context.md).

Client certificate verification needs three pieces of material, not one, and the relationship between them is the whole security property. This part builds them and makes that relationship explicit, because "which certificate goes where" is otherwise something people copy rather than understand.

## What a CA is here

A **certificate authority** is a key pair whose public half is distributed to verifiers, plus a policy — however informal — about whom it will sign for.

Signing a certificate is one assertion: *the holder of this public key is the entity named in this certificate.* Nothing more. It does not say the holder is trustworthy, authorized, or still employed; it says the CA vouched for the name at signing time.

That makes the verification question mechanical. When the gateway receives a client certificate, it asks: is this certificate signed by a key I hold the public half of? If yes, the name in it is as good as the CA's word. If no, the connection is refused.

For edge mutual TLS the practical consequence is that **the CA defines the population**. Every client the CA signs for can connect; no client it has not signed for can. Deciding who gets a certificate *is* the access control decision, made when the certificate is issued rather than when the request arrives — which is why [Part 3](./course-03-handshake-failures-and-identity.md) spends its time on what remains to be decided afterwards.

## Three certificates, two relationships

```text
                    ┌──────────────────────┐
                    │  CA                  │   ca.key  (secret, kept by you)
                    │  CN=ica-ca           │   ca.crt  (public, given to verifiers)
                    └───────┬──────┬───────┘
                    signs   │      │   signs
                ┌───────────┘      └────────────┐
                ▼                               ▼
   ┌──────────────────────┐        ┌──────────────────────┐
   │ SERVER certificate   │        │ CLIENT certificate   │
   │ CN=booking.ica.local │        │ CN=client.ica.local  │
   │ + key                │        │ + key                │
   └──────────┬───────────┘        └──────────┬───────────┘
              │                               │
   held by the gateway,             held by the caller,
   presented to clients             presented to the gateway
              │                               │
              └────────── verified against ca.crt ─────────┘
                          (each side checks the other)
```

The two leaf certificates are structurally identical — both are "a name, a public key, a CA signature". What differs is who holds them and which direction they are presented in. In a production PKI they would also differ in their **extended key usage**, marking one for server authentication and one for client authentication, and a strict verifier checks it. The playground's are unmarked, which `openssl` and Envoy both accept here; it is worth knowing the field exists before wondering why a certificate from a corporate CA is rejected in one direction and not the other.

## Issuing them

A self-signed CA takes one command; each leaf takes two — a CSR, then a signature.

> [!TIP]
> **Try it — create a CA and issue both certificates**
>
> ```sh
> openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
>   -keyout /tmp/ca.key -out /tmp/ca.crt -subj "/CN=ica-ca/O=ica"
>
> openssl req -nodes -newkey rsa:2048 -keyout /tmp/booking.key -out /tmp/booking.csr \
>   -subj "/CN=booking.ica.local/O=ica"
> openssl x509 -req -days 365 -in /tmp/booking.csr -CA /tmp/ca.crt -CAkey /tmp/ca.key \
>   -CAcreateserial -out /tmp/booking.crt
>
> openssl req -nodes -newkey rsa:2048 -keyout /tmp/client.key -out /tmp/client.csr \
>   -subj "/CN=client.ica.local/O=ica"
> openssl x509 -req -days 365 -in /tmp/client.csr -CA /tmp/ca.crt -CAkey /tmp/ca.key \
>   -CAcreateserial -out /tmp/client.crt
>
> openssl x509 -in /tmp/client.crt -noout -subject -issuer
> ```
>
> Expect something like:
>
> ```text
> subject=CN = client.ica.local, O = ica
> issuer=CN = ica-ca, O = ica
> ```
>
> The shape to notice in those two lines: the client certificate's **subject** is the client, its **issuer** is the CA. That relationship is the whole verification — the gateway will accept any certificate whose issuer chain reaches `ica-ca`, and reject everything else. The `openssl x509 -req` steps print "Certificate request self-signature ok" to stderr; that is normal.

Reading the commands as a pattern rather than three incantations:

- **`openssl req`** creates a certificate *request*. With `-x509` it skips the request and self-signs immediately, which is what makes the first command produce a finished CA in one step.
- **`openssl x509 -req`** takes a CSR and signs it with a CA key — the operation a real CA performs. `-CAcreateserial` maintains the serial-number file a CA needs to keep issued certificates distinguishable.
- **`-nodes`** leaves each private key unencrypted, because nothing here can be prompted for a passphrase.
- **`-subj`** supplies the Subject non-interactively, which is what stops `openssl` asking six questions.

Six files result, and only four of them ever leave this machine:

| File | Goes to | Never share |
| --- | --- | --- |
| `ca.key` | nowhere | **yes** — whoever holds it can mint clients |
| `ca.crt` | the gateway secret, as `ca.crt` | no, it is public |
| `booking.crt` / `booking.key` | the gateway secret | the key, yes |
| `client.crt` / `client.key` | the caller | the key, yes |

`ca.key` is the one that matters. A leaked server key exposes one host; a leaked CA key lets anyone issue a client certificate the gateway will accept, silently, with nothing in the logs to distinguish it from a legitimate one.

## A note on names

The server certificate's `CN` must match the hostname clients ask for, because they check it (or would, without `curl -k`). The **client** certificate's `CN` is checked against nothing at all — the gateway verifies the signature chain, not the name.

That is worth stating explicitly because it is the first thing people assume otherwise. Naming a client certificate `client.ica.local` is a convention for humans reading logs. If the name is to mean something enforceable, something downstream has to read it — which is [Part 3](./course-03-handshake-failures-and-identity.md).

> *The CA's signature is the only thing being verified, so the population of clients that can connect is exactly the population the CA has signed for.*

## Reference

- [`openssl req`](https://docs.openssl.org/master/man1/openssl-req/) — creating requests and self-signed certificates; `-x509`, `-nodes`, `-subj`.
- [`openssl x509`](https://docs.openssl.org/master/man1/openssl-x509/) — signing a CSR with `-req`, and reading a certificate with `-subject` / `-issuer`.
- [Secure gateways task](https://istio.io/latest/docs/tasks/traffic-management/ingress/secure-ingress/) — Istio's mutual-TLS section uses the same three-certificate setup.
