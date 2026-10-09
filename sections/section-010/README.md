# Section 010: Workload Identity And Mutual TLS

Every security rule in this course eventually matches on one string — a workload's mesh identity. This section is where that string comes from, how you make a workload prove it, and how to turn the proof on in a cluster that is already running without breaking the callers who were not ready.

Three modules, in dependency order. Module 1 opens a certificate and reads the identity out of it, because a policy written against an identity you assumed rather than checked is the most common failure in the whole domain. Module 2 makes that identity mandatory with `PeerAuthentication`, at each of its three scopes. Module 3 is the procedure for doing so on a live namespace: measure, write down, mesh, enforce.

**Curriculum item covered:** Configuring Authentication (mTLS, JWT)

---

## What You Will Master

- The SPIFFE URI form `spiffe://<trust-domain>/ns/<namespace>/sa/<service-account>`, and that identity comes from the service account rather than the pod.
- Reading a workload certificate's SAN with `istioctl proxy-config secret` and `openssl`, and converting it into a policy `principals` value.
- Certificate lifetime, automatic rotation by `istio-agent`, and what `meshConfig.trustDomain` breaks when it changes.
- `PeerAuthentication` at mesh, namespace and workload scope, and the narrowest-wins precedence between them.
- `STRICT`, `PERMISSIVE`, `DISABLE` and `UNSET`, and the connection-reset failure signature a `STRICT` server produces.
- Reading `connection_security_policy` off `istio_requests_total` to prove no plaintext remains before enforcing.
- `portLevelMtls` exceptions on container ports, and why a client-side `DestinationRule` with `tls.mode: DISABLE` breaks a `STRICT` server with `503 UC`.
- Reading the mode a pod really uses with `istioctl x describe pod` and its inbound listener.

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
    Parts, in reading order:
    1. [Two Callers, One Default](./module-02/course-01-two-callers-one-default.md)
    2. [Require The Handshake With STRICT](./module-02/course-02-require-the-handshake.md)
    3. [Three Scopes, Narrowest Wins](./module-02/course-03-three-scopes-narrowest-wins.md)
    4. [Read The Mode Off The Ship](./module-02/course-04-read-the-mode-off-the-ship.md)
    5. [An Exception For One Port](./module-02/course-05-an-exception-for-one-port.md)
    6. [Client And Server Must Agree](./module-02/course-06-client-and-server-must-agree.md)
    7. [Wrap-Up: Mission Debrief](./module-02/course-07-wrap-up.md)
*   **Hands-on Playground:** `sections/section-010/module-02/playground`: the Starfleet on the planet `starfleet` (sidecars on), plus the `drifter` on the planet `outpost` (no sidecar), so there is a plain-text caller to refuse. No `PeerAuthentication` and no `DestinationRule` yet.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-010/module-02/playground
    ```
*   **Graded labs:** three missions, each right after the part it tests.
    *   **[Enforce mTLS At Three Scopes](./module-02/labs/lab-01/README.md)**: read the [task](./module-02/labs/lab-01/question.md), solve it, then
        ```bash
        astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/module-02/labs/lab-01
        astrona submit -c sections/section-010/module-02/labs/lab-01
        ```
    *   **[Open One Port For The Drifter](./module-02/labs/lab-02/README.md)**: read the [task](./module-02/labs/lab-02/question.md), solve it, then
        ```bash
        astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/module-02/labs/lab-02
        astrona submit -c sections/section-010/module-02/labs/lab-02
        ```
    *   **[Fix The Broken Handshake](./module-02/labs/lab-03/README.md)**: read the [task](./module-02/labs/lab-03/question.md), solve it, then
        ```bash
        astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/module-02/labs/lab-03
        astrona submit -c sections/section-010/module-02/labs/lab-03
        ```

### 3. Migrate A Namespace From PERMISSIVE To STRICT mTLS
*   **Module Reader:** **[Module 3: Migrate A Namespace From PERMISSIVE To STRICT mTLS](./module-03/course.md)**
    Parts, in reading order:
    1. [Count The Plain Signals](./module-03/course-01-count-the-plain-signals.md)
    2. [Write Down Where You Stand](./module-03/course-02-write-down-where-you-stand.md)
    3. [Bring The Drifter Into The Fleet](./module-03/course-03-bring-the-drifter-into-the-fleet.md)
    4. [Switch To STRICT For Good](./module-03/course-04-switch-to-strict-for-good.md)
    5. [Wrap-Up: Mission Debrief](./module-03/course-05-wrap-up.md)
*   **Hands-on Playground:** `sections/section-010/module-03/playground`: the Starfleet on the planet `starfleet` with no `PeerAuthentication`, so it runs in the default `PERMISSIVE` mode. The planet `outpost` has sidecar injection switched off, and its `drifter` still sends plain signals. You move the drifter into the mesh during the module.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-010/module-03/playground
    ```
*   **Graded lab:** **[Migrate A Namespace To STRICT mTLS](./module-03/labs/lab-01/README.md)**: read the
    [task](./module-03/labs/lab-01/question.md), solve it, then
    ```bash
    astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/module-03/labs/lab-01
    astrona submit -c sections/section-010/module-03/labs/lab-01
    ```

Each playground is ungraded: it spins up, prepares the environment, and waits. There is no task and no `astrona submit`. Tear one down with `astrona destroy <name>` when you are finished — the name is printed in each module's playground callout.

---

## Capstone

**[Workload Identity And Mutual TLS Capstone](./capstone/labs/lab-01/)** — Combine all three modules: enforce mTLS mesh-wide, carve one workload exception, and authorize on a certificate identity you read yourself.

Work it after every module in this section, without looking at the
walkthrough. It is graded the same way the module labs are.

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-010/capstone/labs/lab-01
astrona submit -c sections/section-010/capstone/labs/lab-01
```
