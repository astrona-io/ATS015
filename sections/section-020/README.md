# Authorization Policy Fundamentals

Mutual TLS proves a caller is *someone* in the mesh. It has no opinion about whether that someone should be calling this service, on this path, with this method. `AuthorizationPolicy` is where that question is answered, and it is the object the exam tests hardest.

Two modules. Module 1 builds permissions up from nothing: the allow-nothing baseline, the `from` / `to` / `when` structure of a rule, and identity-based rules. Those rules only work when mutual TLS is on, because the ID badge they check is proved in the mTLS handshake. Module 2 is the other direction — `DENY`, the fixed evaluation order it sits in, and why an `ALLOW` can never rescue traffic a `DENY` matched.

**Curriculum item covered:** Configuring Authorization

---

## What You Will Master

- Why `spec: {}` denies everything for the workloads it selects, and that default-deny is created by the first `ALLOW` policy rather than switched on.
- The three parts of a rule — `from.source`, `to.operation`, `when` — and that every part present must match while lists inside one part are ORed.
- `principals`, `namespaces` and `ipBlocks` as sources, and why `principals` cannot work without mTLS.
- That multiple `ALLOW` policies on one workload combine as a union, so adding policies can only permit more.
- The `CUSTOM` → `DENY` → `ALLOW` evaluation order, and that a `DENY` match ends the decision.
- What a workload selected only by `DENY` policies allows.
- `AUDIT` for testing a rule against live traffic without changing any response.
- Reading `notPaths` / `notMethods` / `notPrincipals` correctly, especially inside a `DENY`.
- Telling an authorization `403` apart from a transport-level connection reset.

---

<!-- astrona:playground -->