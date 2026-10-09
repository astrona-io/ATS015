# Section 050: Authorization At The Edge

Inside the mesh, a policy can match on the identity the mesh gave each workload. At the edge that identity does not exist: the caller is on the internet, has no service account, and may show no certificate. What you often have instead is an address.

One module. It applies `AuthorizationPolicy` to the ingress gateway rather than to a workload, and spends its time on the difference that decides whether such a rule works or only looks like it does: `ipBlocks` matches the connection peer, `remoteIpBlocks` matches the client named in `X-Forwarded-For`, and behind a load balancer only one of them is ever right.

**Curriculum item covered:** Configuring Authorization

---

## What You Will Master

- Writing an `AuthorizationPolicy` that guards the ingress gateway, in the gateway's own namespace and with the gateway pod's labels.
- `ipBlocks`: the address of whoever opened the connection. Behind a load balancer, or a port forward, that is the relay, not the client.
- `remoteIpBlocks`: the client address the gateway reads from the `X-Forwarded-For` header.
- `numTrustedProxies`: how many relays the gateway trusts. Set it with `meshConfig.defaultConfig.gatewayTopology.numTrustedProxies` or the gateway's `proxy.istio.io/config` annotation, and prove it with `xffNumTrustedHops` in the gateway's listener. Too low and the gate sees a relay; too high and a client can fake its address.
- That a refusal at the gate is an ordinary `403`, and that the refused signal never reaches the app.
- Opening one path to one network with a `DENY` rule and `notRemoteIpBlocks`, without closing the rest of the gate.
- Reading the gateway's access log to see the decision and the client address side by side.
- Where address rules help, and where a client certificate or a token is the control you really need.

---

## The Learning Path

### 1. Authorize By Source IP At The Ingress Gateway
*   **Module Reader:** **[Module 1: Authorize By Source IP At The Ingress Gateway](./module-01/course.md)**
    Parts, in reading order:
    1. [Guard The Arrival Gate](./module-01/course-01-guard-the-arrival-gate.md)
    2. [Who Opened The Connection: `ipBlocks`](./module-01/course-02-who-opened-the-connection.md)
    3. [Trust The Right Number Of Relays](./module-01/course-03-trust-the-right-number-of-relays.md)
    4. [Block A Client Range With `remoteIpBlocks`](./module-01/course-04-block-a-client-range.md)
    5. [One Path, One Network](./module-01/course-05-one-path-one-network.md)
    6. [Wrap-Up: Mission Debrief](./module-01/course-06-wrap-up.md)
*   **Hands-on Playground:** `sections/section-050/module-01/playground`: the Starfleet on the planet `starfleet`, Istio 1.30.5 installed with Helm, and the ingress gateway `istio-ingress` (label `istio=ingress`) on its own planet `istio-ingress`. A `Gateway` and `VirtualService` for `starfleet.example.com` are ready. `astrona run` keeps two port forwards open: `127.0.0.1:8080` to the gateway's port `80` and `127.0.0.1:8443` to its port `443`. No `AuthorizationPolicy`, and `numTrustedProxies` is not set: you set it.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-050/module-01/playground
    ```
*   **Graded labs:** two missions, each right after the part it tests.
    *   **[Block A Client Range At The Gateway](./module-01/labs/lab-01/README.md)**: read the [task](./module-01/labs/lab-01/question.md), solve it, then
        ```bash
        astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-050/module-01/labs/lab-01
        astrona submit -c sections/section-050/module-01/labs/lab-01
        ```
    *   **[Open One Path To One Network](./module-01/labs/lab-02/README.md)**: read the [task](./module-01/labs/lab-02/question.md), solve it, then
        ```bash
        astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-050/module-01/labs/lab-02
        astrona submit -c sections/section-050/module-01/labs/lab-02
        ```

**No load balancer on `kind`.** The port forward ends inside the gateway pod, so the gateway sees every signal come from `127.0.0.1`. That is itself one of the module's lessons.

The playground is ungraded: it spins up, prepares the environment, and waits. There is no task and no `astrona submit`. Tear it down with `astrona destroy <name>` when you are finished — the name is printed in the module's playground callout.

---

## Capstone

**[Edge Authorization Capstone](./capstone/labs/lab-01/)** — Layer a path-scoped address allow-list over a global deny-list at the gateway, and get the precedence right.

Work it after every module in this section, without looking at the
walkthrough. It is graded the same way the module labs are.

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-050/capstone/labs/lab-01
astrona submit -c sections/section-050/capstone/labs/lab-01
```
