# Case Study: LAB015-050-01 — Block A Client Range At The Gateway

> The formal version is the [exam question](./exam-question.md); the full answer
> is the [step-by-step guide](./step-by-step-guide.md).

## Scenario

A range of addresses has been hammering the booking API. Abuse has asked you to
cut it off at the edge — not at the application, which is already spending
connections on traffic nobody wants.

There is a load balancer in front of the gateway, and the first attempt someone
made at this blocked either nobody or everybody, depending on which field they
used.

## What good looks like

- Requests from the offending range are refused before they enter the mesh.
- Everyone else is unaffected, including other hostnames the shared gateway
  serves.
- The rule reads the client's real address, and reads it from a position that an
  attacker cannot control.
- A denied caller gets an ordinary HTTP refusal, not a mysterious dropped
  connection.

## Hints

1. There are two source-address fields and they mean genuinely different things.
   One of them is the load balancer, always.
2. The field you want reads a header. Ask yourself why that is safe here, and
   what makes it unsafe elsewhere.
3. The policy does not live next to the application. Which namespace, and what
   does its selector have to match?
4. Choose the action carefully: this gateway serves more than your hostname, and
   an allow-list with no narrowing closes all of it.

## Going further

Once it passes, repeat it with one or two changes so the skill becomes flexible:

- Combine the IP rule with a path rule so only `/admin` is IP-restricted.
- Set `numTrustedProxies: 2` and work out which element of `X-Forwarded-For` is then used.
- Apply the same policy to an egress gateway and restrict who may use the egress path.
