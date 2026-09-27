# Section 050: Authorization At The Edge

Section 020 authorized traffic already inside the mesh, matching on identities the mesh itself issued. At the edge those do not exist: the caller is on the internet, has no service account, and may present no certificate. What you often have instead is an address.

One module. It applies `AuthorizationPolicy` to the ingress gateway rather than to a workload, and spends its time on the distinction that decides whether such a rule is correct or merely decorative: `ipBlocks` matches the connection peer, `remoteIpBlocks` matches the client named in `X-Forwarded-For`, and behind a load balancer only one of them is ever right.

**Curriculum item covered:** Configuring Authorization

---

## What You Will Master

- Writing an `AuthorizationPolicy` that selects the ingress gateway, in the gateway's own namespace.
- `ipBlocks` as the direct TCP peer — and why that is the load balancer, not the user, in most real topologies.
- `remoteIpBlocks` as the originating client from `X-Forwarded-For`.
- `meshConfig.gatewayTopology.numTrustedProxies`: what it pins, why the rule is spoofable without it, and what goes wrong when the number does not match reality.
- That a gateway-scoped denial is an ordinary `403`, and that the request never reaches the application.
- Why a `kubectl port-forward` makes source-IP rules behave unexpectedly, and reading the gateway access log instead of guessing.
- Where address-based rules genuinely help, and where a client certificate or a JWT is the control the requirement actually needs.

---

## The Learning Path

### 1. Authorize By Source IP At The Ingress Gateway
*   **Module Reader:** **[Module 1: Authorize By Source IP At The Ingress Gateway](./module-01/course.md)**
    Deep-dive parts, in reading order:
    1. [Authorizing at the gateway, and the connection peer](./module-01/course-01-authorizing-at-the-gateway.md)
    2. [`X-Forwarded-For` and trusted proxies](./module-01/course-02-trusting-x-forwarded-for.md)
    3. [Verifying, and where address rules fit](./module-01/course-03-verifying-and-design.md)
*   **Hands-on Playground:** `sections/section-050/module-01/playground` — namespace `gwauthz-demo` with a `Gateway` and `VirtualService` for `booking.ica.local` already applied as the target of your policies. No `AuthorizationPolicy`, and no `numTrustedProxies` set.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-050/module-01/playground
    ```
*   **Graded lab:** **[Block A Client Range At The Gateway](./module-01/labs/lab-01/)** — read the
    [exam question](./module-01/labs/lab-01/docs/exam-question.md), solve it, then
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-050/module-01/labs/lab-01
    astrona submit -c .
    ```

**No load balancer on `kind`.** Reach the gateway with `kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80`, and remember that a port-forward makes the connection appear to come from inside the cluster — which is itself one of the module's lessons.

The playground is ungraded: it spins up, prepares the environment, and waits. There is no task and no `astrona submit`. Tear it down with `astrona destroy <name>` when you are finished — the name is printed in the module's playground callout.

---

## Capstone

**[Edge Authorization Capstone](./capstone/labs/lab-01/)** — Layer a path-scoped address allow-list over a global deny-list at the gateway, and get the precedence right.

Work it after every module in this section, without looking at the
walkthrough. It is graded the same way the module labs are.

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-050/capstone/labs/lab-01
astrona submit -c .
```
