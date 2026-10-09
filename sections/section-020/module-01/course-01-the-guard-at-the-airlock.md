# Where Authorization Is Enforced

Before you write a single rule, find out where the check runs and who configures it. Almost every confusing thing about `AuthorizationPolicy` follows from one fact. The check runs in the sidecar proxy of the pod that **receives** the request, and it runs only after the mTLS handshake has worked.

A sidecar proxy (Envoy) is a proxy container Istio adds to each pod; all inbound and outbound traffic of the pod passes through it. This part shows the path a request takes, proves that a workload with no policy lets every request in, and shows where to look when a request is denied.

## The path a request takes

A request that arrives at a workload passes several checks, always in the same order. Each check belongs to a different Istio object. Knowing the order tells you which object to blame when something fails.

### Four checks, in a fixed order

Here is what happens inside the receiving pod's proxy:

```mermaid
flowchart TB
    S["caller"] -->|"request"| H["mTLS check"]
    H -->|"no certificate"| X["connection reset"]
    H -->|"certificate verified"| P["HTTP is read"]
    P --> J["JWT check"]
    J -->|"bad token"| E1["401"]
    J --> G["authorization check"]
    G -->|"no rule matches"| E2["403"]
    G -->|"allowed"| A["the app"]
```

The diagram shows four stages. The mTLS check is `PeerAuthentication`, the JWT check is `RequestAuthentication`, and the authorization check is `AuthorizationPolicy`. A request stopped at an early stage never reaches a later one. For requests from outside the cluster, the ingress gateway's own proxy runs the same checks at the edge of the mesh.

### What the order means for you

Three facts follow from that order, and the exam tests all three:

- **The authorization check only sees requests that mTLS already accepted.** A `STRICT` rejection happens at the first stage. No rule is read, because there is no request yet. So a cut connection and a `403` point at different objects.
- **The caller's identity comes from mTLS.** A `principals` rule compares the identity in the caller's certificate. With no mTLS there is no certificate, and the rule has nothing to compare.
- **Token facts come from the JWT check.** A JWT (JSON Web Token) is a signed token that carries claims about the end user. Rules on a JWT need a `RequestAuthentication` to run first.

## Who configures the check

You never configure the check inside the proxy by hand. The control plane (`istiod`) does it for you. The way it does it explains how fast a change works, and why a policy can exist without doing anything.

### From policy to filter

`istiod` reads every `AuthorizationPolicy` and works out which pods each one selects. It then turns the matching rules into configuration for those pods' proxies. Inside Envoy, the check is a filter called **RBAC**, short for role-based access control.

Two facts follow:

- **The `selector` decides which pods get the policy.** A policy whose selector matches no pod is a valid object, and `kubectl get` shows it. But no proxy ever receives it.
- **The decision is local.** The proxy does not ask `istiod` about each request. It checks the request against the configuration it already holds. That is why a new policy works within seconds and costs no measurable time per request.

HTTP fields like `methods` and `paths` only work on ports the proxy reads as HTTP. On a plain TCP port, the proxy can only check connection facts such as identity, namespace, address and port.

## No policy means every request gets in

If no `AuthorizationPolicy` selects a workload, its proxy has no RBAC rules. Every request that passes mTLS goes straight to the app. That is not a hole in the mesh: Istio stays out of the way until you ask. It is the same choice as `PERMISSIVE` being the default for mTLS.

### See it in your playground

<!-- astrona:playground:renew -->

The commands below need the three helpers from the module's landing page. First check that no policy exists yet, anywhere:

```sh
kubectl get authorizationpolicy -A
```

```text
No resources found
```

Now send requests to the probe from both clients inside the mesh:

```sh
from_shuttle http://probe:8000/get
from_fortio http://probe:8000/get
```

```text
200 200 200 <- http://probe:8000/get
Code 200
```

Both get in. The `shuttle` and `fortio` pods have different identities, and mTLS verified both. But no RBAC filter checked either identity, because no policy exists to check it against.

### A request the authorization check never sees

Now try the `drifter`. It has no sidecar and no certificate:

```sh
from_drifter http://probe.starfleet:8000/get
```

```text
drifter: 000
command terminated with exit code 56
```

`000` means no HTTP response came back at all. The `STRICT` `PeerAuthentication` cut the connection at the first stage. That is the mTLS check at work, not authorization. Remember this: a cut connection is never an `AuthorizationPolicy` problem.

## Where a denial is visible

The check runs at the receiving workload, so the caller learns almost nothing when it is denied. It gets `403` and the body `RBAC: access denied`. It does not learn which policy denied it, or which rule it failed.

The evidence lives with the workload that denied the request:

- the **access log** of its `istio-proxy`, which records the request, the `403` and the policy that decided;
- its **proxy configuration**, which holds the RBAC rules it really received;
- `kubectl get authorizationpolicy -A`, which shows every policy that could select it.

> [!TIP]
> Send the test request from the caller, then look for the reason on the receiver. Searching the caller's log for an authorization problem is the most common way to lose twenty minutes on the exam.

## Common pitfalls

> [!WARNING]
> - **Debugging authorization when the problem is mTLS.** A cut connection (`000`, curl exit code `56`) never reached the authorization check. Check for a status code before you blame a policy.
> - **Expecting a `principals` rule to work without mTLS.** The RBAC filter can only use the identity that mTLS verified.
> - **Assuming a policy applies because it exists.** It applies only to the pods its `selector` matches, checked by those pods' own proxies.
> - **Looking at the caller for the reason.** The caller only sees `403`. The access log of the receiving workload says why.

> *Authorization runs in the receiving pod's proxy, after mTLS and after HTTP is read. That is why a cut connection and a `403` are failures of different objects, and why the reason is always on the receiver.*
