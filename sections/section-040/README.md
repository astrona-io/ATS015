# Section 040: Securing Edge Traffic With TLS

Inside the mesh, Istio issues both certificates and mutual TLS happens without being asked for. At the edge none of that holds: the caller is a browser or an external system, the certificate must be one that caller already trusts, and you supply it.

Four modules. The first three cover one `Gateway` TLS mode each. Module 1 is `SIMPLE` — ordinary server-side HTTPS, and the namespace rule that makes almost everyone's first attempt fail. Module 2 is `MUTUAL`, requiring a client certificate signed by a CA you nominate. Module 3 is `PASSTHROUGH`, where the gateway forwards an encrypted stream it cannot read and routes on SNI alone. Module 4 looks at signals that leave the mesh: the app sends plain HTTP, and its own sidecar adds the TLS seal on the way out. This is called TLS origination.

**Curriculum item covered:** Securing Edge Traffic with TLS

---

## What You Will Master

- `credentialName` naming a Secret in the **gateway pod's** namespace (`istio-ingress` in the playgrounds, `istio-system` with an `istioctl` install), not the application's.
- The port block that a TLS listener depends on: `protocol: HTTPS` on `443`. The port `name` is only a label.
- `kubectl create secret tls` for `SIMPLE`, and why `MUTUAL` needs `create secret generic` with `tls.crt`, `tls.key` **and** `ca.crt`.
- `tls.httpsRedirect` on a port-80 listener, and why the `tls` block belongs there at all.
- What a client rejected during a TLS handshake observes, and why it is never an HTTP status.
- That a successful request does not prove a `MUTUAL` gateway checks client certificates: read the `-cacert` secret and `requireClientCertificate` from the gateway's proxy. A `MUTUAL` gateway with no CA turns everyone away.
- `protocol: TLS` with `mode: PASSTHROUGH`, and routing with a `VirtualService` `tls` block matching `sniHosts`.
- Everything passthrough gives up at the edge — path and header routing, rewrites, L7 telemetry, and every authorization rule that mentions methods, paths or hosts.
- Proving which end terminated TLS by reading the certificate the handshake actually returned.
- A `ServiceEntry` port `80` with `targetPort: 443` and a `DestinationRule` with `tls.mode: SIMPLE`, so the sidecar seals an app's plain `http://` call to an outside service.
- `subjectAltNames` to check an outside server's certificate name, and the three failures `400`, `WRONG_VERSION_NUMBER` and `CERTIFICATE_VERIFY_FAILED`.

---

## The Learning Path

### 1. Terminate TLS At The Ingress Gateway
*   **Module Reader:** **[Module 1: Terminate TLS At The Ingress Gateway](./module-01/course.md)**
    Parts, in reading order:
    1. [Give The Gate Its Certificate](./module-01/course-01-give-the-gate-its-certificate.md)
    2. [Open The HTTPS Door](./module-01/course-02-open-the-https-door.md)
    3. [Redirect And Rotate](./module-01/course-03-redirect-and-rotate.md)
    4. [When The Handshake Fails](./module-01/course-04-when-the-handshake-fails.md)
    5. [Wrap-Up: Mission Debrief](./module-01/course-05-wrap-up.md)
*   **Hands-on Playground:** `sections/section-040/module-01/playground`: the Starfleet on the planet `starfleet`, Istio 1.30.5 installed with Helm, and the ingress gateway `istio-ingress` on its own planet `istio-ingress`. `astrona run` keeps two port forwards open: `127.0.0.1:8080` to the gateway's port `80` and `127.0.0.1:8443` to its port `443`. No certificate, Secret, `Gateway` or `VirtualService` yet: you make them.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-040/module-01/playground
    ```
*   **Graded labs:** two missions, each right after the part it tests.
    *   **[Serve HTTPS At The Ingress Gateway](./module-01/labs/lab-01/README.md)**: read the [task](./module-01/labs/lab-01/question.md), solve it, then
        ```bash
        astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-01/labs/lab-01
        astrona submit -c sections/section-040/module-01/labs/lab-01
        ```
    *   **[Repair The Gate's Certificate](./module-01/labs/lab-02/README.md)**: read the [task](./module-01/labs/lab-02/question.md), solve it, then
        ```bash
        astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-01/labs/lab-02
        astrona submit -c sections/section-040/module-01/labs/lab-02
        ```

### 2. Require Client Certificates At The Edge
*   **Module Reader:** **[Module 2: Require Client Certificates At The Edge](./module-02/course.md)**
    Parts, in reading order:
    1. [Issue The Fleet's Badges](./module-02/course-01-issue-the-fleet-badges.md)
    2. [Make The Gate Ask For A Badge](./module-02/course-02-make-the-gate-ask-for-a-badge.md)
    3. [Turn Away Strangers And Prove It](./module-02/course-03-turn-away-strangers-and-prove-it.md)
    4. [Two Secret Layouts And What A Badge Proves](./module-02/course-04-two-secret-layouts-and-what-a-badge-proves.md)
    5. [Wrap-Up: Mission Debrief](./module-02/course-05-wrap-up.md)

    You make your own certificate authority (CA) with `openssl`, give the gate a secret with `tls.crt`, `tls.key` and `ca.crt`, and switch it to `MUTUAL`. Then you watch a visitor with no client certificate, or one from another CA, get turned away in the handshake, and prove the check from the gateway's own proxy. The last part shows the second layout, with the CA in its own `-cacert` secret.
*   **Hands-on Playground:** `sections/section-040/module-02/playground`: the Starfleet on the planet `starfleet`, Istio 1.30.5 installed with Helm, and the ingress gateway `istio-ingress` on its own planet `istio-ingress`. `astrona run` keeps two port forwards open: `127.0.0.1:8080` to the gateway's port `80` and `127.0.0.1:8443` to its port `443`. No certificate, secret, `Gateway` or `VirtualService` yet: you make them.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-040/module-02/playground
    ```
*   **Graded labs:** two missions, each right after the part it tests.
    *   **[Require Client Certificates At The Edge](./module-02/labs/lab-01/README.md)**: read the [task](./module-02/labs/lab-01/question.md), solve it, then
        ```bash
        astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-02/labs/lab-01
        astrona submit -c sections/section-040/module-02/labs/lab-01
        ```
    *   **[Fix The Gate's Trusted Badge Office](./module-02/labs/lab-02/README.md)**: read the [task](./module-02/labs/lab-02/question.md), solve it, then
        ```bash
        astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-02/labs/lab-02
        astrona submit -c sections/section-040/module-02/labs/lab-02
        ```

### 3. TLS Passthrough Instead Of Termination
*   **Module Reader:** **[Module 3: TLS Passthrough Instead Of Termination](./module-03/course.md)**
    Parts, in reading order:
    1. [What A Proxy Can See](./module-03/course-01-what-a-proxy-can-see.md)
    2. [Open A Gate That Does Not Decrypt](./module-03/course-02-open-a-gate-that-does-not-decrypt.md)
    3. [Prove Who Opened The Envelope](./module-03/course-03-prove-who-opened-the-envelope.md)
    4. [When The Stream Has Nowhere To Go](./module-03/course-04-when-the-stream-has-nowhere-to-go.md)
    5. [One Gate, Two Modes](./module-03/course-05-one-gate-two-modes.md)
    6. [Wrap-Up: Mission Debrief](./module-03/course-06-wrap-up.md)

    You set up a gate that passes a sealed signal through unopened, route it on the SNI name alone, and prove from the certificate that the ship at the end opened it. Then you break the setup three ways and learn to read the gate's listener instead of the status code. Last, one gate ends TLS for one host and passes another through.
*   **Hands-on Playground:** `sections/section-040/module-03/playground`: the Starfleet and the shuttle on the planet `starfleet`, plus the vault (`tls-backend`), an nginx that makes its own certificate and ends TLS itself on port `8443`. Istio 1.30.5 is installed with Helm, with the ingress gateway `istio-ingress` on its own planet `istio-ingress`. The bridge is already behind the gate over plain HTTP. `astrona run` keeps two port forwards open: `127.0.0.1:8080` to the gateway's port `80` and `127.0.0.1:8443` to its port `443`. No TLS secret: passthrough needs none.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-040/module-03/playground
    ```
*   **Graded labs:** two missions, each right after the part it tests.
    *   **[Route An Encrypted Stream By SNI](./module-03/labs/lab-01/README.md)**: read the [task](./module-03/labs/lab-01/question.md), solve it, then
        ```bash
        astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-03/labs/lab-01
        astrona submit -c sections/section-040/module-03/labs/lab-01
        ```
    *   **[Fix The Gate That Routes Nothing](./module-03/labs/lab-02/README.md)**: read the [task](./module-03/labs/lab-02/question.md), solve it, then
        ```bash
        astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-03/labs/lab-02
        astrona submit -c sections/section-040/module-03/labs/lab-02
        ```

### 4. Originate TLS For External Services
*   **Module Reader:** **[Module 4: Originate TLS For External Services](./module-04/course.md)**
    Parts, in reading order:
    1. [Who Seals The Signal](./module-04/course-01-who-seals-the-signal.md)
    2. [Chart The Planet And Seal The Signal](./module-04/course-02-chart-the-planet-and-seal-the-signal.md)
    3. [Check The Planet's ID Card](./module-04/course-03-check-the-planets-id-card.md)
    4. [A Seal On The Wrong Channel](./module-04/course-04-a-seal-on-the-wrong-channel.md)
    5. [Use What You Won](./module-04/course-05-use-what-you-won.md)
    6. [Wrap-Up: Mission Debrief](./module-04/course-06-wrap-up.md)

    The shuttle calls `http://httpbin.org`, and its own sidecar seals the signal and sends it to port `443`. You add the two objects one at a time and see what each half does on its own. Then you make the sidecar check the server's certificate name, break the setup on purpose to learn the three failures, and put a timeout on an outside HTTPS service.
*   **Hands-on Playground:** `sections/section-040/module-04/playground`: the shuttle on the planet `starfleet`, Istio 1.30.5 installed with Helm, no gateway. It needs outbound internet access to `httpbin.org`. No `ServiceEntry`, `DestinationRule` or `VirtualService` yet: you make them.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-040/module-04/playground
    ```
*   **Graded lab:** one mission, right after the part it tests.
    *   **[Seal The Signal To An Outside Planet](./module-04/labs/lab-01/README.md)**: read the [task](./module-04/labs/lab-01/question.md), solve it, then
        ```bash
        astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-040/module-04/labs/lab-01
        astrona submit -c sections/section-040/module-04/labs/lab-01
        ```

**No load balancer on `kind`.** A gateway Service never gets an outside address on `kind`; that is expected, not a fault. The playgrounds reach the gateway through the port forwards `astrona run` keeps open (`127.0.0.1:8080` and `127.0.0.1:8443`, see `astrona port-forward list`). The labs tell you which `kubectl port-forward` to start.

Each playground is ungraded: it spins up, prepares the environment, and waits. There is no task and no `astrona submit`. Tear one down with `astrona destroy <name>` when you are finished — the name is printed in each module's playground callout.

---

## Capstone

**[Edge TLS Capstone](./capstone/labs/lab-01/)** — One gateway, two hostnames, two modes: terminate TLS for one and pass the other through untouched, with HTTP redirected.

Work it after every module in this section, without looking at the
walkthrough. It is graded the same way the module labs are.

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-040/capstone/labs/lab-01
astrona submit -c .
```
