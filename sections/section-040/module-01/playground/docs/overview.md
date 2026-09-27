# Overview: Terminate TLS At The Ingress Gateway (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, applies the starting workloads, and then waits. There is
no task, no `astrona submit`, and no pass/fail. Explore, break things,
`astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster with `kubectl` already pointed at it.
- **Istio 1.30.5**, installed with the `demo` profile — which includes the
  `istio-ingressgateway` Deployment in `istio-system` — plus `istioctl` and
  `openssl` on your PATH.
- One injected namespace, **`tls-demo`**: `booking-service-v1` (serving
  `/book`) and `notification-service-v1`, both fronted by Services on port 80.
- **No `Gateway`, no `VirtualService`, no TLS secret.**

> **No load balancer on `kind`.** The `istio-ingressgateway` Service stays at
> `EXTERNAL-IP: <pending>`. That is expected. Reach the gateway with
> `kubectl -n istio-system port-forward svc/istio-ingressgateway 8443:443`.

## Things to try

- Create the TLS secret in `tls-demo` instead of `istio-system` and find every
  symptom of the mistake: the `Gateway` applies, the listener does not come up,
  `istioctl proxy-config secret` shows nothing.
- Name the port `web` instead of `https` and see what changes.
- Call the gateway without `--resolve` (so no SNI) and compare the failure with
  the wrong-namespace one.
- Serve two hostnames from one `Gateway`, each with its own certificate, and
  confirm which one SNI selects.
- Replace the secret with a certificate for a different `CN` and watch the
  gateway serve it without any restart. Time it.
- Add `minProtocolVersion: TLSV1_3`, then force an older version with
  `curl --tls-max 1.2` and read the failure.
- Add the port-80 redirect, then remove `hosts` from it and see what the
  listener does.
- Compare `istioctl proxy-config listener deploy/istio-ingressgateway
  -n istio-system --port 443` before and after each change.

## When you're done

```sh
astrona destroy ats-015-playground-040-01
```

(`astrona destroy` takes the environment name, not the config path.)
