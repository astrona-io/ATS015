# HTTP Fields In TCP Rules

A policy that works on an HTTP service often gets copied to a TCP workload with its fields unchanged. Istio accepts the object. The result is not an error. It is a policy that behaves differently from what the author expects, and the difference depends on the action. This chapter tests one HTTP-only field, `methods`, in an `ALLOW` rule and in a `DENY` rule, and ends with the rule that keeps a `DENY` safe.

<!-- astrona:playground:renew -->

## Why the proxy cannot match a method

A method such as `GET` belongs to an HTTP request. On a TCP connection the proxy has no method to compare. Istio documents the result: when a rule is applied to TCP traffic, the HTTP-based attributes (`hosts`, `methods` and `paths`) cannot be processed. The two actions then handle the missing attribute in opposite ways, and each way is the safe one for its action.

For an `ALLOW` rule, an attribute the proxy cannot process makes the rule invalid, and Istio ignores the rule. An ignored `ALLOW` rule matches nothing, so the connection falls to default-deny. For a `DENY` rule, a missing attribute counts as a match. A `DENY` that cannot check a condition denies, because the safe error for a block list is to block.

## An ALLOW rule with a method

Delete the policies from the last chapter, then apply an `ALLOW` policy that adds `methods` to a port rule:

```sh
kubectl delete authorizationpolicy --all -n starfleet
```

Save this as `authorizationpolicy-tcp-allow-methods.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: tcp-policy
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: tcp-echo
  action: ALLOW
  rules:
  - to:
    - operation:
        methods: ["GET"]
        ports: ["9000"]
```

Apply it, wait, and connect to both Service ports:

```sh
kubectl apply -f authorizationpolicy-tcp-allow-methods.yaml
tcp_from shuttle tcp-echo 9000
tcp_from shuttle tcp-echo 9001
```

Both lines print `refused`, including port `9000`, which the rule names. The invalid rule is ignored, so the workload has an `ALLOW` policy with no usable rule, and everything is refused. The policy looks like "allow GET on port 9000", and it allows nothing.

## A DENY rule with only a method

Now switch to a `DENY` rule that has only the method. Save this as `authorizationpolicy-tcp-deny-methods.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: tcp-policy
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: tcp-echo
  action: DENY
  rules:
  - to:
    - operation:
        methods: ["GET"]
```

Apply it and connect again:

```sh
kubectl apply -f authorizationpolicy-tcp-deny-methods.yaml
tcp_from shuttle tcp-echo 9000
tcp_from shuttle tcp-echo 9001
```

Both lines print `refused`. The proxy cannot read the method, treats the rule as a match, and denies every TCP connection to the workload. A `DENY` meant to block `GET` closed the whole server.

## Name a port in the DENY

Add a port to the same operation. Both fields now sit in one `operation`, so both must fit. The method cannot be read, and the port can. Change the file so the operation reads:

```yaml
    - operation:
        methods: ["GET"]
        ports: ["9000"]
```

Apply the file and test both ports:

```sh
kubectl apply -f authorizationpolicy-tcp-deny-methods.yaml
tcp_from shuttle tcp-echo 9000
tcp_from shuttle tcp-echo 9001
```

Port `9000` prints `refused` and port `9001` prints `allowed`. The rule matches only connections to port `9000`, because the method counts as a match and the port decides. A `DENY` has no `ALLOW` policy to fall back on, so the workload allows everything the `DENY` does not match. This is the recommendation in the reference: scope a `DENY` rule to a specific port, so a field the proxy cannot read cannot widen it.

## Common pitfalls

> [!WARNING]
> - **An HTTP-only field in an `ALLOW` rule.** The rule is ignored and the workload refuses everything. Remove the field, or move the workload to an HTTP port.
> - **An HTTP-only field in a `DENY` rule without a port.** The workload denies all TCP traffic.
> - **Trusting that an accepted object works.** Istio accepts the object without an error. Prove each policy with a connection that should pass and one that should fail.
