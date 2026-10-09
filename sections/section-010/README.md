# Section 010: Workload Identity And Mutual TLS

Every security rule in this course eventually matches on one string — a workload's mesh identity. This section is where that string comes from, how you make a workload prove it, and how to turn the proof on in a cluster that is already running without breaking the callers who were not ready.

Three modules, in dependency order. Module 1 opens a certificate and reads the identity out of it, because a policy written against an identity you assumed rather than checked is the most common failure in the whole domain. Module 2 makes that identity mandatory with `PeerAuthentication`, at each of its three scopes. Module 3 is the procedure for doing so on a live namespace: measure, exempt, mesh, enforce.

**Curriculum item covered:** Configuring Authentication (mTLS, JWT)

---

## What You Will Master

- The SPIFFE URI form `spiffe://<trust-domain>/ns/<namespace>/sa/<service-account>`, and that identity comes from the service account rather than the pod.
- Reading a workload certificate's SAN with `istioctl proxy-config secret` and `openssl`, and converting it into a policy `principals` value.
- Certificate lifetime, automatic rotation by `istio-agent`, and what `meshConfig.trustDomain` breaks when it changes.
- `PeerAuthentication` at mesh, namespace and workload scope, and the narrowest-wins precedence between them.
- `STRICT`, `PERMISSIVE`, `DISABLE` and `UNSET`, and the connection-reset failure signature a `STRICT` server produces.
- Reading `connection_security_policy` off `istio_requests_total` to prove no plaintext remains before enforcing.
- `portLevelMtls` exceptions on container ports, and why a client-side `DestinationRule` with `tls.mode: DISABLE` breaks a `STRICT` server.

---

## The Learning Path

### 1. Inspect Workload Identity And Certificates
*   **Module Reader:** **[Module 1: Inspect Workload Identity And Certificates](./module-01/course.md)**
    Parts, in reading order:
    1. [How A Ship Gets Its Badge](./module-01/course-01-how-a-ship-gets-its-badge.md)
    2. [Read The Badge A Ship Carries](./module-01/course-02-read-the-badge-a-ship-carries.md)
    3. [From Badge To Guest List](./module-01/course-03-from-badge-to-guest-list.md)
    4. [Wrap-Up: Mission Debrief](./module-01/course-04-wrap-up.md)
*   **Hands-on Playground:** `sections/section-010/module-01/playground`: a `kind` cluster with Istio and the Starfleet on the planet `starfleet`. Every ship runs under its own service account, so every ship carries its own badge; `fortio` runs as `default`, and the `drifter` on the planet `outpost` has no sidecar and no badge at all. No security rule of any kind.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-010/module-01/playground
    ```
*   **Graded lab:** **[Prove A Workload Identity And Authorize On It](./module-01/labs/lab-01/README.md)**: read the
    [task](./module-01/labs/lab-01/question.md), solve it, then
    ```bash
    astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/module-01/labs/lab-01
    astrona submit -c sections/section-010/module-01/labs/lab-01
    ```

### 2. Enforce mTLS With PeerAuthentication At Three Scopes
*   **Module Reader:** **[Module 2: Enforce mTLS With PeerAuthentication At Three Scopes](./module-02/course.md)**
    Deep-dive parts, in reading order:
    1. [Modes, and what they do to the inbound listener](./module-02/course-01-modes-and-the-inbound-listener.md)
    2. [The three scopes and how precedence resolves](./module-02/course-02-scopes-and-precedence.md)
    3. [Proving what is in effect](./module-02/course-03-proving-what-is-in-effect.md)
*   **Hands-on Playground:** `sections/section-010/module-02/playground` — namespace `mtls-demo` (injected) plus `outside` (deliberately not injected), so a plaintext caller exists to be refused.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-010/module-02/playground
    ```
*   **Graded lab:** **[Enforce mTLS At Three Scopes](./module-02/labs/lab-01/)** — read the
    [exam question](./module-02/labs/lab-01/docs/exam-question.md), solve it, then
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-010/module-02/labs/lab-01
    astrona submit -c .
    ```

### 3. Migrate A Namespace From PERMISSIVE To STRICT mTLS
*   **Module Reader:** **[Module 3: Migrate A Namespace From PERMISSIVE To STRICT mTLS](./module-03/course.md)**
    Deep-dive parts, in reading order:
    1. [Measuring before you change anything](./module-03/course-01-measuring-with-telemetry.md)
    2. [Exceptions, and moving callers into the mesh](./module-03/course-02-exceptions-and-meshing.md)
    3. [Enforcing, verifying and rolling back](./module-03/course-03-enforcing-and-rolling-back.md)
*   **Hands-on Playground:** `sections/section-010/module-03/playground` — namespace `migrate-demo` with no `PeerAuthentication` at all, and an unmeshed `outside-client` you migrate into the mesh during the module.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-010/module-03/playground
    ```
*   **Graded lab:** **[Migrate A Namespace To STRICT mTLS](./module-03/labs/lab-01/)** — read the
    [exam question](./module-03/labs/lab-01/docs/exam-question.md), solve it, then
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-010/module-03/labs/lab-01
    astrona submit -c .
    ```

Each playground is ungraded: it spins up, prepares the environment, and waits. There is no task and no `astrona submit`. Tear one down with `astrona destroy <name>` when you are finished — the name is printed in each module's playground callout.

---

## Capstone

**[Workload Identity And Mutual TLS Capstone](./capstone/labs/lab-01/)** — Combine all three modules: enforce mTLS mesh-wide, carve one workload exception, and authorize on a certificate identity you read yourself.

Work it after every module in this section, without looking at the
walkthrough. It is graded the same way the module labs are.

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-010/capstone/labs/lab-01
astrona submit -c .
```
