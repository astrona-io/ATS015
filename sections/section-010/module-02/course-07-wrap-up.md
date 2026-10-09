# Wrap-Up

You have finished every part and every lab in this module. Before you move on, look back at what you learned, check yourself, and clean up the playground.

## What you learned

This module was about one object, `PeerAuthentication`, which decides whether a receiving workload requires mTLS, and about the `DestinationRule` setting that decides what the sending sidecar uses.

**From [Two Callers, One Default](./course-01-two-callers-one-default.md):**

- mTLS means both sides present a certificate signed by `istiod`, and the connection between them is encrypted.
- The name in the certificate is a SPIFFE ID, `spiffe://cluster.local/ns/<namespace>/sa/<service account>`. It belongs to the service account, not the pod.
- With no policy, every workload is `PERMISSIVE`: it accepts mTLS and plain text. Auto mTLS makes meshed callers use mTLS by themselves.
- `200` proves nothing about mTLS. The `X-Forwarded-Client-Cert` header on the receiving side shows the caller's identity when the request used mTLS.
- The inbound listener peeks at the first bytes (`tls_inspector`) and picks the mTLS chain or the plain-text chain.

**From [Require mTLS With STRICT](./course-02-require-the-handshake.md):**

- The four modes: `PERMISSIVE` (both), `STRICT` (mTLS only), `DISABLE` (plain text only) and `UNSET` (ask the wider policy).
- `STRICT` removes the plain-text chain. A caller without a sidecar gets `000` and `curl` exit code `56`: a reset connection, not an HTTP error.
- The refused connection leaves only a short line in the receiver's access log: no request, and `NR filter_chain_not_found`.
- `000` points at `PeerAuthentication`. `403 RBAC: access denied` points at an authorization rule.

**From [Three Scopes, Narrowest Wins](./course-03-three-scopes-narrowest-wins.md):**

- Scope is not a field. In `istio-system` with no `selector` is mesh-wide; in an app namespace with no `selector` is namespace-wide; with a `selector` is a workload policy.
- The narrowest policy wins and decides alone: port, then workload, then namespace, then mesh. A `PERMISSIVE` namespace policy beats a `STRICT` mesh policy.
- A mesh-wide policy in the wrong namespace, or a `selector` added by mistake, applies without any error.

**From [Read The mTLS Mode A Pod Uses](./course-04-read-the-mode-off-the-ship.md):**

- `kubectl get peerauthentication -A` lists every policy and its mode.
- `istioctl x describe pod` shows the mode that won and lists every policy that covers the pod. The narrowest one in the list decides.
- `istioctl proxy-config listener <pod> --port 15006` shows the inbound filter chains: `Trans: tls` only under `STRICT`, plus `Trans: raw_buffer` under `PERMISSIVE`.
- Prove a policy with real traffic first, then confirm with `istioctl` that the sidecar received it.

**From [An Exception For One Port](./course-05-an-exception-for-one-port.md):**

- `portLevelMtls` sets the mode for single ports, inside a workload policy with a `selector`.
- Its key is the **container port** (`8080` for the probe), not the Service port (`8000`). A Service port as the key is accepted and silently does nothing.

**From [Client And Server Must Agree](./course-06-client-and-server-must-agree.md):**

- `PeerAuthentication` controls what a workload accepts. A `DestinationRule` with `trafficPolicy.tls.mode` controls what callers send.
- `tls.mode: DISABLE` on the caller against a `STRICT` server gives `503 UC` in the caller's access log.
- `ISTIO_MUTUAL` is what auto mTLS picks anyway. Once you set `tls.mode`, auto mTLS no longer decides for that host.
- A `DISABLE` server makes auto mTLS send plain text: nothing breaks, but the caller's identity is gone.

## Your missions

You proved each skill in a graded lab, right after the part that taught it:

| Lab | After the part | What you proved |
| --- | --- | --- |
| [Enforce mTLS At Three Scopes](./labs/lab-01/README.md) | Three Scopes, Narrowest Wins | build mesh, namespace and workload policies where the narrowest wins |
| [Open One Port With portLevelMtls](./labs/lab-02/README.md) | An Exception For One Port | open one container port on a strict workload, and nothing else |
| [Fix A DestinationRule That Breaks mTLS](./labs/lab-03/README.md) | Client And Server Must Agree | find a client-side `tls.mode: DISABLE` behind a `503 UC` and fix it without weakening the server |

If you skipped one, go back to it now. Each lab is short, and the exam asks for exactly these skills.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. No <code>PeerAuthentication</code> exists anywhere. Does a pod without a sidecar get an answer from a meshed pod?</summary>

Yes. The default mode is `PERMISSIVE`, so the meshed pod accepts plain text as well as mTLS.
</details>

<details>
<summary>2. A caller without a sidecar gets <code>000</code> and exit code <code>56</code>. A meshed caller gets <code>403</code>. Which object do you look at for each?</summary>

The `000` is a refused connection: look at `PeerAuthentication` (a `STRICT` mode). The `403` came after the request was read: look at the authorization rules.
</details>

<details>
<summary>3. You save a <code>PeerAuthentication</code> named <code>default</code> with <code>mode: STRICT</code> and no <code>selector</code> in the namespace <code>starfleet</code>. Is it mesh-wide?</summary>

No. Only a policy in the root namespace, `istio-system`, is mesh-wide. In `starfleet` it covers that namespace only.
</details>

<details>
<summary>4. The mesh-wide policy says <code>STRICT</code>, the <code>starfleet</code> namespace policy says <code>PERMISSIVE</code>. Does the drifter reach the probe?</summary>

Yes. The narrowest policy decides alone, and the namespace policy is narrower than the mesh-wide one.
</details>

<details>
<summary>5. The probe's Service port is <code>8000</code> and its container port is <code>8080</code>. Which key goes in <code>portLevelMtls</code>?</summary>

`8080`, the container port. The sidecar's listener only knows the ports the pod listens on. A key of `8000` is accepted and does nothing.
</details>

<details>
<summary>6. Two meshed, healthy workloads. The caller's access log shows <code>503 UC</code>. The server is <code>STRICT</code>. What do you check first?</summary>

The `DestinationRule` for the server's host. A `trafficPolicy.tls.mode: DISABLE` makes the caller send plain text, and the strict server closes the connection. Set it to `ISTIO_MUTUAL` or remove the `tls` block.
</details>

<details>
<summary>7. How do you prove which policy decides the mode of one pod?</summary>

`istioctl x describe pod <pod> -n <namespace>`. It prints the effective mode and every policy that covers the pod. The narrowest policy in that list is the one that decides.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and any lab that is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-015-playground-010-02
```

If `astrona list` also showed a lab, remove it the same way, for example:

```sh
astrona destroy ats-015-lab-010-02-03
```

Then check that everything is gone:

```sh
astrona list
```

```text
No astrona labs running.
```

You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.

> *A `PeerAuthentication` decides what a workload accepts, at the narrowest scope that covers it; a `DestinationRule` decides what callers send. Both sides must agree.*
