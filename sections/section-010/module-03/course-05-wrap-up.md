# Wrap-Up

You have moved a whole namespace from `PERMISSIVE` to `STRICT` mTLS (mutual TLS) without cutting off a single client. Before you move on, look back at what you learned, check yourself, and clean up the playground.

## What you learned

This module was about a procedure, not a new object: count, write down, move the clients, measure again, and only then switch.

**From [Count Plain-Text Requests To A Workload](./course-01-count-the-plain-signals.md):**

- Every proxy counts its requests in `istio_requests_total`. The label `connection_security_policy` is `mutual_tls` for requests that arrived with mTLS and `none` for plain-text ones.
- Read it on the **receiving** workload's proxy, with `pilot-agent request GET stats/prometheus` in the `istio-proxy` container.
- `source_workload="unknown"` with `none` means a client outside the mesh. The receiving proxy's access log shows the client's address, and `-` instead of a TLS server name for a plain-text request.
- A counter proves the past, not the future. Measure longer than your slowest regular client. Counters only go up, and a pod restart wipes them.

**From [Write Down The Current mTLS Mode](./course-02-write-down-where-you-stand.md):**

- With no `PeerAuthentication`, the mode is `PERMISSIVE`. Write it down as a `default` policy: it makes the choice visible, and it is your rollback file.
- A `STRICT` refusal is a connection reset: `000` and curl exit code 56, not a `403`.
- Switching and rolling back both take seconds (at most about a minute), with no restart.
- Safe order: `PERMISSIVE` first, check every client, then `STRICT`. To undo, go back to `PERMISSIVE` before you remove sidecars from clients.
- A client that can never use mTLS can keep one port open with `portLevelMtls` in a policy with a `selector`. The key is the container port, not the Service port.

**From [Inject A Sidecar Into A Plain-Text Client](./course-03-bring-the-drifter-into-the-fleet.md):**

- Sidecar injection is a webhook that runs only when a pod is created. Labelling a namespace changes nothing for running pods.
- `kubectl rollout restart` is the real migration step. A bare pod with no controller does not come back.
- The new pod keeps the same identity, because identity comes from the namespace and service account.
- After the move, check that the `none` count stopped going up, not that it is zero.

**From [Switch The Namespace To STRICT mTLS](./course-04-switch-to-strict-for-good.md):**

- One `default` policy with `mode: STRICT` switches the whole namespace. Prove it with real requests and with `istioctl x describe pod`.
- A client `DestinationRule` with `tls.mode: DISABLE` breaks a `STRICT` server even when both workloads have sidecars: the client gets `503` with the flag `UC`.
- Keep the `PERMISSIVE` file at hand and decide the rollback trigger in advance.

## The graded lab

You proved the whole procedure in a graded lab, right after the part that finished it:

| Lab | After the part | What you proved |
| --- | --- | --- |
| [Migrate A Namespace To STRICT mTLS](./labs/lab-01/README.md) | Switch The Namespace To STRICT mTLS | move the last plain-text client into the mesh, then switch a namespace to `STRICT` |

If you skipped it, go back to it now. The lab is short, and the exam asks for exactly these skills.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. You read <code>connection_security_policy</code> on the client's proxy and see only <code>mutual_tls</code>. Is the server safe to switch?</summary>

No. The client's proxy only tells you what that one client sent. Plain-text requests from clients you do not know about only show up on the **receiving** workload's proxy. Read the counter there.
</details>

<details>
<summary>2. After you move the last client, <code>none</code> still shows 10. Did the move fail?</summary>

Not necessarily. Counters only go up while the pod lives, so the old plain-text requests stay in the total. Send new requests and check that the `none` number stopped going up.
</details>

<details>
<summary>3. You label a namespace with <code>istio-injection=enabled</code>. The pods still show <code>1/1</code>. Why?</summary>

The injection webhook only runs when a pod is created. Pods that were already running are not touched. Restart them, for example with `kubectl rollout restart deployment <name>`.
</details>

<details>
<summary>4. After switching to <code>STRICT</code>, one client gets a connection reset and another gets <code>503 UC</code>. What is different about them?</summary>

The client with the reset has no sidecar, so it sends plain text and the server closes the connection. The client with `503 UC` has a sidecar, but a `DestinationRule` with `tls.mode: DISABLE` tells its proxy to send plain text. Add a sidecar to the first one, and remove or fix the `DestinationRule` for the second.
</details>

<details>
<summary>5. You want to remove the sidecar from a client of a <code>STRICT</code> namespace. What do you do first?</summary>

Switch the namespace back to `PERMISSIVE`. Undo in the reverse order of the migration. If you remove the sidecar first, the client sends plain text to a `STRICT` server and gets a connection reset.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and any lab that is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-015-playground-010-03
```

If `astrona list` also showed a lab, remove it the same way, for example:

```sh
astrona destroy ats-015-lab-010-03
```

Then check that everything is gone:

```sh
astrona list
```

```text
No astrona labs running.
```

You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.

> *A switch to `STRICT` is ten seconds of typing. The procedure around it is what makes those ten seconds safe.*
