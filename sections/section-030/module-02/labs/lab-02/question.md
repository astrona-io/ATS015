---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

Astronaut, two reports reached mission control from the planet `starfleet`. Administrators in `group1` are refused at the probe's admin path. And the probe's public path, which anyone should be able to read, now asks for a token.

The planet `starfleet` has sidecar injection on and runs:

* `probe-v1` and `probe-v2`: the echo probe behind one `probe` Service on port `8000`. Pods carry the label `app: probe`. Every path below answers `200` when the mesh lets the request through.
* `shuttle`: a client pod with `curl`. Send your test signals from here.

Istio 1.30.5 is installed. Two security objects already exist:

* A `RequestAuthentication` named `probe-jwt`. It checks tokens from the issuer `testing@secure.istio.io` on the probe. **It is correct.**
* An `AuthorizationPolicy` named `probe-access` on the probe. Something in it is wrong.

Two sample tokens from that issuer, with the same subject, are published at `https://raw.githubusercontent.com/istio/istio/release-1.30/security/tools/jwt/samples/`: `demo.jwt` and `groups-scope.jwt`. Decode them to see their claims.

Fix the problem so that:

1.  `probe-access` is the **only** `AuthorizationPolicy` in `starfleet`, with action `ALLOW`.
2.  A request **without** a token to `http://probe:8000/headers` gets `200`.
3.  `GET http://probe:8000/get` gets `403` without a token and `200` with the `demo.jwt` token.
4.  `http://probe:8000/anything/admin` gets `403` without a token, `403` with the `demo.jwt` token, and `200` with the `groups-scope.jwt` token.
5.  The admin rule keeps a `when` condition on the token's group claim with the value `group1`.
6.  The `RequestAuthentication` named `probe-jwt` is **left unchanged**. Leave the Deployments and Services unchanged.

The grader fetches both tokens and sends live signals from the `shuttle` pod, so the fix has to work, not merely exist.
