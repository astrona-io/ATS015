# Close The Whole Path

A `DENY` has the same fields as an `ALLOW`; only the `action` changes. What changes is the cost of a small mistake, astronaut. A guest list that is a little too narrow annoys someone, who reports it. A banned list that is a little too narrow leaves the door you wanted shut wide open, and nobody reports anything.

In this part you write a banned path with a hole in it on purpose, find the hole, and close it.

## How the guard reads a path

The `paths` field of an `operation` accepts four forms. Each form matches a different set of paths, and under `DENY` the paths it does **not** match stay open.

### The four forms

| Form | Matches | Under `DENY`, still reachable |
| --- | --- | --- |
| `/anything/admin` | exactly that path | `/anything/admin/`, `/anything/admin/users` |
| `/anything/admin*` | that path and everything that starts with it | `/anything/api/admin` |
| `*/admin` | every path that ends with `/admin` | `/anything/admin/users` |
| `*` | every path | nothing |

The `*` works as a wildcard only at the start or at the end of a path. A prefix form also matches more than you may think: `/anything/admin*` matches `/anything/administrator` too (we checked: it gets `403`).

### Same combining rules, opposite effect

The rules for combining conditions stay the same under `DENY`: values in one list are combined with OR, different fields and parts with AND, and separate rules with OR. But the effect flips. Under `ALLOW`, more rules let more signals in. Under `DENY`, more rules shut more signals out.

A part you leave out does not limit anything. In an `ALLOW`, a missing `from` makes the guest list generous. In a `DENY`, a missing `from` makes the ban cover every caller. Often that is what you want, but make it a choice, not an accident.

## Find the hole

Here you ban an admin area on the probe with an exact path, then test a path one level deeper. The probe echoes any path under `/anything/`, so every signal that gets past the guard answers `200`.

<!-- astrona:playground:renew -->

### Start clean

Remove every policy on the planet, so only the policy in this part decides:

```sh
kubectl delete authorizationpolicy --all -n starfleet
```

### Ban the exact path

Save this as `authorizationpolicy-probe-deny-admin.yaml`:

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

The path you tested is shut, so the policy looks like it works. But `/anything/admin/users` answers `200`: the whole admin area behind the first door is open.

## Close it with a prefix

The fix is one character. Change the path in your file to the prefix form, so it covers the admin path and everything under it.

### Ban the whole area

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

Now the whole admin area is shut. `/anything/api/admin` still answers, because it does not start with `/anything/admin`. Whether that path matters depends on your app; the point is that you checked it.

> [!TIP]
> When you test a `DENY`, test the thing you did **not** write. If the rule names `/admin*`, try `/api/admin`. If it names one method, try another. A `DENY` that you only tested on the case it obviously covers has not been tested.

### Exceptions go inside the ban

Say `/anything/admin/health` must stay reachable while the rest of the area is shut. An `ALLOW` cannot reopen it, because the guard reads the `DENY` first. Write the exception into the `DENY` rule itself. Both fields sit in the same `operation`, so both must fit for the ban to apply:

```yaml
    - operation:
        paths: ["/anything/admin*"]
        notPaths: ["/anything/admin/health"]
```

Read it as: "deny signals whose path starts with `/anything/admin` **and** is not `/anything/admin/health`."

## Common pitfalls

> [!WARNING]
> - **An exact path where you meant a prefix.** `paths: ["/admin"]` leaves `/admin/users` open, and a test of `/admin` alone reports success.
> - **A `*` in the middle of a path.** It is not a wildcard there. On our test system, `paths: ["/anything/*/admin"]` did not refuse `/anything/x/admin`; it only matched a path with a real `*` character in it.
> - **Trying to carve out an exception with an `ALLOW`.** Put the exception in the `DENY` rule, for example with `notPaths`.
> - **Forgetting that a missing `from` covers every caller.** Under `DENY`, an empty part is sweeping, not harmless.

> *Under `DENY`, a missing `*` is a hole and a missing part is a sweep. Test the path you did not write.*

## Your mission: Close A Path With DENY

You can now ban a whole path area and prove that no guest list reopens it. Now prove it in a graded mission: allow a service's normal call, ban its admin path and everything beneath it, and keep a careless `ALLOW` for that path in place without opening anything.

This mission runs on its own small app, not on the Starfleet: `notification-service`, `booking-service` and a `tester` client in the namespace `deny-demo`. The `question.md` describes it.

The mission runs in its own training solar system, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-015-playground-020-02
```

Then start the mission:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-020/module-02/labs/lab-01
```

Read the task in [`question.md`](./labs/lab-01/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-02/labs/lab-01
```

When the mission is done, remove it and wake your playground up again:

```sh
astrona destroy ats-015-lab-020-02
astrona start ats-015-playground-020-02
```
