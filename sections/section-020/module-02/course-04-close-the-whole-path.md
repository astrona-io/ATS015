# Deny A Path With Prefix Matching

A `DENY` has the same fields as an `ALLOW`; only the `action` changes. What changes is the cost of a small mistake. An `ALLOW` policy that is a little too narrow blocks someone, who reports it. A `DENY` policy that is a little too narrow leaves open the path you wanted closed, and nobody reports anything.

This chapter shows how the `paths` field matches a request, and why the form you choose matters so much under `DENY`. Then you write a `DENY` path with a gap in it on purpose, find the gap, and close it.

## How a path is matched

The `paths` field of an `operation` accepts four forms. Each form matches a different set of paths, and under `DENY` the paths it does **not** match stay open:

| Form | Matches | Under `DENY`, still reachable |
| --- | --- | --- |
| `/anything/admin` | exactly that path | `/anything/admin/`, `/anything/admin/users` |
| `/anything/admin*` | that path and everything that starts with it | `/anything/api/admin` |
| `*/admin` | every path that ends with `/admin` | `/anything/admin/users` |
| `*` | every path | nothing |

The `*` works as a wildcard only at the start or at the end of a path. A prefix form also matches more than you may think: `/anything/admin*` matches `/anything/administrator` too (we checked: it gets `403`).

The rules for combining conditions stay the same under `DENY`. Values in one list are combined with OR, different fields and parts with AND, and separate rules with OR. But the effect flips. Under `ALLOW`, more rules let more requests in; under `DENY`, more rules keep more requests out.

The same flip applies to a part you leave out, because a missing part does not limit anything. In an `ALLOW`, a missing `from` makes the policy allow every caller. In a `DENY`, a missing `from` makes it deny every caller. Often that is what you want, but make it a choice, not an accident.

## Find the gap

The table predicts that an exact path leaves everything beneath it open. To see it for real, you deny an admin area on the probe with an exact path, then test a path one level deeper. The probe echoes any path under `/anything/`, so every request that gets past the sidecar proxy answers `200`.

<!-- astrona:playground:renew -->

Remove every policy in the namespace first, so only the policy in this chapter decides:

```sh
kubectl delete authorizationpolicy --all -n starfleet
```

Then deny the exact path. Save this as `authorizationpolicy-probe-deny-admin.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-deny-admin
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: DENY
  rules:
  - to:
    - operation:
        paths: ["/anything/admin"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-probe-deny-admin.yaml
```

`kubectl` prints the same TCP port warning as for every `DENY` that uses only HTTP fields, then `authorizationpolicy.security.istio.io/probe-deny-admin created`. The probe only speaks HTTP, so you can ignore the warning here.

Wait up to about a minute, then test the path you wrote and one level deeper:

```sh
from_shuttle $PROBE/anything/admin
from_shuttle $PROBE/anything/admin/users
```

```text
403 403 403 <- shuttle http://probe:8000/anything/admin
200 200 200 <- shuttle http://probe:8000/anything/admin/users
```

The path you tested is closed, so the policy looks like it works. But `/anything/admin/users` answers `200`: everything beneath the exact path is still open.

## Close it with a prefix

The fix is one character. Change the path in your file to the prefix form, so it covers the admin path and everything under it.

Save this as `authorizationpolicy-probe-deny-admin.yaml` (the same file, with `*` added):

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-deny-admin
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: DENY
  rules:
  - to:
    - operation:
        paths: ["/anything/admin*"]
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-probe-deny-admin.yaml
```

Wait up to about a minute, then check the result, including a path the rule does not name:

```sh
from_shuttle $PROBE/anything/admin
from_shuttle $PROBE/anything/admin/users
from_shuttle $PROBE/anything/api/admin
```

```text
403 403 403 <- shuttle http://probe:8000/anything/admin
403 403 403 <- shuttle http://probe:8000/anything/admin/users
200 200 200 <- shuttle http://probe:8000/anything/api/admin
```

Now the whole admin area is closed. `/anything/api/admin` still answers, because it does not start with `/anything/admin`. Whether that path matters depends on your app; the point is that you checked it.

> [!TIP]
> When you test a `DENY`, test the thing you did **not** write. If the rule names `/admin*`, try `/api/admin`. If it names one method, try another. A `DENY` that you only tested on the case it obviously covers has not been tested.

A closed area often needs one hole in it. Say `/anything/admin/health` must stay reachable while the rest of the area is shut. An `ALLOW` cannot reopen it, because the sidecar proxy checks the `DENY` first. So you write the exception into the `DENY` rule itself. Both fields sit in the same `operation`, so both must fit for the `DENY` to apply:

```yaml
    - operation:
        paths: ["/anything/admin*"]
        notPaths: ["/anything/admin/health"]
```

Read it as: "deny requests whose path starts with `/anything/admin` **and** is not `/anything/admin/health`."

Under `DENY`, a missing `*` leaves a gap, and a missing part matches everything. A prefix closes a whole area, an exception goes inside the `DENY` with a field like `notPaths`, and a good test always tries a path the rule does not name. That exception used a negative field, and negative fields inside a `DENY` are easy to read the wrong way round.

## Common pitfalls

> [!WARNING]
> - **An exact path where you meant a prefix.** `paths: ["/admin"]` leaves `/admin/users` open, and a test of `/admin` alone reports success.
> - **A `*` in the middle of a path.** It is not a wildcard there. On our test system, `paths: ["/anything/*/admin"]` did not refuse `/anything/x/admin`; it only matched a path with a real `*` character in it.
> - **Trying to carve out an exception with an `ALLOW`.** Put the exception in the `DENY` rule, for example with `notPaths`.
> - **Forgetting that a missing `from` covers every caller.** Under `DENY`, a missing part matches everything, so it is not harmless.

## Your mission: Close A Path With DENY

You can now deny a whole path area and prove that no `ALLOW` policy reopens it. The graded lab asks you to allow a service's normal call, deny its admin path and everything beneath it, and keep a careless `ALLOW` for that path in place without opening anything.

This lab runs on its own small app, not on the Starfleet: `notification-service`, `booking-service` and a `tester` client in the namespace `deny-demo`. The `question.md` describes it.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-015-playground-020-02
```

Then start the lab:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-020/module-02/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-02/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-015-lab-020-02
astrona start ats-015-playground-020-02
```
