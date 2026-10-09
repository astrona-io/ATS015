---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

Astronaut, your mission: the shuttle keeps sending plain signals to a planet in another solar system, and they must leave the ship sealed.

The planet `starfleet` holds the `shuttle`, a client pod with `curl` and its sidecar. Istio 1.30.5 is installed, the mesh is at its `ALLOW_ANY` default, and every sidecar writes an access log (flight log). There is no `ServiceEntry`, `DestinationRule` or `VirtualService` yet.

The shuttle calls **`http://httpbin.org/get`**, plain HTTP on port `80`. httpbin.org is a public service: it answers with a `"url"` field that shows the scheme it was reached on, `http` or `https`. This lab needs outbound internet access.

Make the shuttle's sidecar originate TLS for these signals:

1.  Create a `ServiceEntry` named **`httpbin-org`** in `starfleet` for host **`httpbin.org`**, with `location: MESH_EXTERNAL` and `resolution: DNS`.
2.  Declare **two** ports on it:
    *   **80**, name `http`, protocol **`HTTP`**, with **`targetPort: 443`**
    *   **443**, name `https`, protocol **`HTTPS`**
3.  Create a `DestinationRule` named **`httpbin-org`** in `starfleet` for host `httpbin.org`. Under `trafficPolicy.portLevelSettings` for **port 80 only**, set:
    *   `tls.mode` to **`SIMPLE`**
    *   `tls.sni` to **`httpbin.org`**
    *   `tls.subjectAltNames` to **`httpbin.org`**, so the sidecar checks the name on the server's certificate
4.  Do **not** use `insecureSkipVerify`, and do not set `tls` at the top level of `trafficPolicy` or for port `443`.
5.  Do not change the shuttle. It keeps calling `http://`, never `https://`.

**What the grader checks**

6.  A signal to `http://httpbin.org/get` from the shuttle is answered with **`"url": "https://httpbin.org/get"`**: the server was reached over TLS.
7.  The shuttle's flight log shows that signal as `"GET /get HTTP/1.1" 200` through the cluster `outbound|80||httpbin.org`, delivered to an address on port **443**.
8.  The shuttle's proxy has a TLS transport socket with SNI `httpbin.org` and a name check for `httpbin.org` on its **port 80** cluster for `httpbin.org`, and **no** TLS transport socket on its port 443 cluster.
9.  The shuttle's own `https://httpbin.org/get` signals still answer **200**.
10. The `ServiceEntry` and `DestinationRule` match points 1 to 4.

The grader sends live signals from the `shuttle` pod and reads the shuttle's proxy, so the seal has to work, not merely exist.
