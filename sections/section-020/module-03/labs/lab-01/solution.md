# Solution Walkthrough

Status: **UNTESTED.** The steps follow the Istio documentation and were never run on a cluster, so this walkthrough shows no command output. Compare your results with the descriptions in each step.

You need two policies on `tcp-echo`: an `ALLOW` policy that names the `shuttle` identity and ports `9000` and `9001`, and a `DENY` policy that closes port `9001`. The `ALLOW` policy also closes port `9002` for everyone, because no rule names it.

---

## Step 1: Paste a test helper

This helper opens a connection from a client pod and prints `allowed` when the reply contains `hello`:

```sh
tcp_from() { out=$(kubectl exec -n starfleet deploy/$1 -c $1 -- sh -c "echo 'port $3' | nc -w 3 $2 $3" 2>&1); case "$out" in *hello*) echo "$1 -> $2:$3 allowed ($out)";; *) echo "$1 -> $2:$3 refused";; esac; }
ECHO_IP=$(kubectl get pod -n starfleet -l app=tcp-echo -o jsonpath='{.items[0].status.podIP}')
```

Before any policy exists, all four connections from the question print `allowed`:

```sh
tcp_from shuttle tcp-echo 9000
tcp_from shuttle tcp-echo 9001
tcp_from shuttle $ECHO_IP 9002
tcp_from relay tcp-echo 9000
```

## Step 2: The ALLOW policy

Save this as `authorizationpolicy-tcp-allow-shuttle.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: tcp-allow-shuttle
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: tcp-echo
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/starfleet/sa/shuttle"]
      to:
        - operation:
            ports: ["9000", "9001"]
```

The principal has no `spiffe://` prefix. The ports are strings. Apply it:

```sh
kubectl apply -f authorizationpolicy-tcp-allow-shuttle.yaml
```

Wait up to about a minute, then run the four connections again. Now only the `relay` connection and the `9002` connection are refused. The `shuttle` still reaches `9000` and `9001`. The `ALLOW` policy selects `tcp-echo`, so every connection that no rule matches is refused, and that includes port `9002` by pod IP.

## Step 3: The DENY policy

Save this as `authorizationpolicy-tcp-deny-9001.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: tcp-deny-9001
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: tcp-echo
  action: DENY
  rules:
    - to:
        - operation:
            ports: ["9001"]
```

The rule uses `ports` only. A `methods` or `paths` field here would be an HTTP-only field, and on a TCP workload it would change what the rule matches. Apply it:

```sh
kubectl apply -f authorizationpolicy-tcp-deny-9001.yaml
```

## Step 4: Prove all four results

Wait up to about a minute and open the four connections from the question:

```sh
tcp_from shuttle tcp-echo 9000
tcp_from shuttle tcp-echo 9001
tcp_from shuttle $ECHO_IP 9002
tcp_from relay tcp-echo 9000
```

Expected: only the first line prints `allowed`. The `shuttle` reaches `9000`. Port `9001` is refused because the `DENY` is checked before the `ALLOW`. Port `9002` is refused because no `ALLOW` rule names it. The `relay` is refused because its identity is not in the `ALLOW` rule.

If the first line prints `refused`, check the principal for a `spiffe://` prefix and check that the ports are strings. If a line you expect to be refused prints `allowed`, a connection that was already open may still use the old rules, so wait and test again.

## Submit

```sh
astrona submit -c sections/section-020/module-03/labs/lab-01
```
