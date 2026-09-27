# Overview: Require Client Certificates At The Edge (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, applies the starting workloads, and then waits. There is
no task, no `astrona submit`, and no pass/fail. Explore, break things,
`astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster with `kubectl` already pointed at it.
- **Istio 1.30.5**, installed with the `demo` profile — including the
  `istio-ingressgateway` Deployment in `istio-system` — plus `istioctl` and
  `openssl` on your PATH.
- One injected namespace, **`mtlsedge-demo`**: `booking-service-v1` (serving
  `/book`) and `notification-service-v1`.
- **No `Gateway`, no `VirtualService`, no secret.** You build the CA and both
  certificates yourself.

> **No load balancer on `kind`.** Reach the gateway with
> `kubectl -n istio-system port-forward svc/istio-ingressgateway 8443:443`.

## Things to try

- Build the secret with `kubectl create secret tls` and watch the gateway come
  up serving TLS while requiring nothing. That is the dangerous failure: it
  looks like it works.
- Name the CA key `cacert` instead of `ca.crt` and check
  `requireClientCertificate` before you test any traffic.
- Make a second CA and a client certificate from it, then connect with that
  certificate. Compare the error with connecting with no certificate at all.
- Look at what the backend receives: enable `X-Forwarded-Client-Cert` handling
  and see which client details reach the application.
- Switch the same listener between `SIMPLE` and `MUTUAL` and diff the proxy
  listener JSON.
- Put the CA in a separate `booking-credential-mtls-cacert` secret instead and
  see whether this Istio version picks it up.
- Leave the mesh fully `PERMISSIVE` behind a `MUTUAL` gateway and convince
  yourself the two are unrelated.

## When you're done

```sh
astrona destroy ats-015-playground-040-02
```

(`astrona destroy` takes the environment name, not the config path.)
