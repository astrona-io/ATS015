# Module 020-03 hand-over (UNTESTED)

Everything in this module was written from the official Istio TCP authorization task and the AuthorizationPolicy reference. Nothing was run on a cluster (`astrona run`, `astrona test` and the validator were not run).

Open assumptions to check on a cluster:

- `course-01`: the exact output of `istioctl proxy-config listener ... | grep -c rbac`, and that a TCP rule appears as `envoy.filters.network.rbac`.
- `course-01`: the `drifter` plain-text connection is closed by `STRICT` (expected, not observed).
- `course-02`: what a refused connection looks like in the `tcp-echo` access log.
- Lab 01: `nc -w 3` behaviour in the `curlimages/curl` image (busybox `nc`), and whether a refused connection returns an empty reply (the validator treats "no `hello`" as refused).
- Lab 01: `solution.md` shows no command output on purpose.
