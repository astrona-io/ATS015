# Section 040: Securing Edge Traffic With TLS

Inside the mesh, Istio issues both certificates and mutual TLS happens without being asked for. At the edge none of that holds: the caller is a browser or an external system, the certificate must be one that caller already trusts, and you supply it.

Three modules, one per `Gateway` TLS mode. Module 1 is `SIMPLE` — ordinary server-side HTTPS, and the namespace rule that makes almost everyone's first attempt fail. Module 2 is `MUTUAL`, requiring a client certificate signed by a CA you nominate. Module 3 is `PASSTHROUGH`, where the gateway forwards an encrypted stream it cannot read and routes on SNI alone.

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
    Deep-dive parts, in reading order:
    1. [What a proxy can see in a TLS stream](./module-03/course-01-what-a-proxy-can-see.md)
    2. [Configuring passthrough](./module-03/course-02-configuring-passthrough.md)
    3. [What passthrough costs](./module-03/course-03-what-passthrough-costs.md)
*   **Hands-on Playground:** `sections/section-040/module-03/playground` — namespace `passthrough-demo` with an nginx backend that generates its own certificate at startup and terminates TLS itself. No secret in `istio-system`, because this mode needs none.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-040/module-03/playground
    ```
*   **Graded lab:** **[Route An Encrypted Stream By SNI](./module-03/labs/lab-01/)** — read the
    [exam question](./module-03/labs/lab-01/docs/exam-question.md), solve it, then
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-040/module-03/labs/lab-01
    astrona submit -c .
    ```

**No load balancer on `kind`.** In all three playgrounds the `istio-ingressgateway` Service stays at `EXTERNAL-IP: <pending>`; that is expected, not a fault. Reach the gateway with `kubectl -n istio-system port-forward svc/istio-ingressgateway 8443:443`.

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
