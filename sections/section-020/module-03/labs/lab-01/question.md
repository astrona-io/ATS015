---
estimated_duration: 25m
---

# Question

Solve this question on: `terminal`

The namespace `starfleet` has sidecar injection on and a `PeerAuthentication` in `STRICT` mode. It runs:

* `tcp-echo`: a plain TCP server with the label `app: tcp-echo`. It listens on ports `9000`, `9001` and `9002` and replies with `hello` followed by the text it receives. Its Service lists only ports `9000` and `9001`. Port `9002` is reachable only by pod IP.
* `shuttle`: a client pod with `nc`, service account `shuttle`.
* `relay`: a second client pod with `nc`, service account `relay`.

Istio 1.30.5 is installed. No `AuthorizationPolicy` exists yet.

On `tcp-echo`, in the namespace `starfleet`:

1. **Allow** connections from the `shuttle` identity to ports `9000` and `9001`, and from no other caller.
2. **Deny** every connection to port `9001`, from every caller, with a `DENY` policy. Scope the `DENY` with `ports` only: use no HTTP-only field.
3. Leave port `9002` unreachable for every caller, including the `shuttle`.

The result, with each connection opened by `nc` from the named client:

| From | To | Expected |
| --- | --- | --- |
| `shuttle` | `tcp-echo:9000` | reply that contains `hello` |
| `shuttle` | `tcp-echo:9001` | refused, no reply |
| `shuttle` | `<tcp-echo pod IP>:9002` | refused, no reply |
| `relay` | `tcp-echo:9000` | refused, no reply |

Constraints:

* Do not change the Deployments, Services or the `PeerAuthentication`.
* Do not use `methods`, `paths` or `hosts` in any rule.
* Do not solve requirement 1 with a `namespaces` or `ipBlocks` rule: the rule must name the identity.

The grader checks that an `ALLOW` policy with `principals` and a `DENY` policy exist. Then it opens the four connections above, so the policies have to work, not merely exist.
