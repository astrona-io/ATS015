---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

Astronaut, the planet `migrate-demo` has to move to `STRICT` mutual TLS (mTLS) this week. It has run in the mesh for months, and nobody ever chose its mode: it inherited `PERMISSIVE` and stayed there. One caller is still outside the mesh.

The cluster runs Istio 1.30.5 (`demo` profile) and two namespaces:

* **`migrate-demo`** has sidecar injection switched on. It runs `booking-service-v1`, `notification-service-v1` (container port `8084`, Service `notification-service` on port `80`) and a `tester` client pod with `curl`. There is no `PeerAuthentication`, so it is `PERMISSIVE`.
* **`outside`** has no sidecar injection. It runs one `outside-client` pod with `curl`. It calls `http://notification-service.migrate-demo/notify` with plain signals.

Get `migrate-demo` to `STRICT` mTLS **without breaking `outside-client`**:

1.  Show, from the receiving proxy's counters (`connection_security_policy` on `istio_requests_total`), that plain signals arrive today. This step is not graded, but do it first: it tells you the switch is not safe yet.
2.  Bring `outside-client` into the mesh where it is. It must end up running with an `istio-proxy` container.
3.  Create a `PeerAuthentication` named **`default`** in `migrate-demo`, with **no `selector`**, in mode **`STRICT`**.
4.  Afterwards, both `tester` and `outside-client` must still get `200` from `POST http://notification-service.migrate-demo/notify`.

Constraints:

* Do not delete `outside-client`, and do not move it into `migrate-demo`.
* Do not solve step 3 with a workload policy (a policy with a `selector`): the whole namespace is in scope.
* Do not change the application Deployments, Services or ConfigMaps in `migrate-demo`.

The grader checks that `outside-client` carries a sidecar, that `migrate-demo` has a namespace-wide `STRICT` policy, that both callers still get `200`, and that the `notification-service` proxy really requires a client certificate on port `8084`.
