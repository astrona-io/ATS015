# Section 030: End-User Authentication With JWT

A request usually carries two identities: the workload making the call, and the end user on whose behalf it is made. Sections 010 and 020 covered the first. This section covers the second, which arrives as a JSON Web Token in a header rather than as a certificate.

Two modules, and the first exists mainly to correct an expectation. Module 1 shows that `RequestAuthentication` validates a token *if one is present* and requires nothing — so protecting a service always takes two objects. Module 2 goes past "a valid token exists" to what the token actually says, matching on claims such as `groups` and `scope`.

**Curriculum items covered:** Configuring Authentication (mTLS, JWT) — module 1; Configuring Authorization — module 2.

---

## What You Will Master

- `RequestAuthentication` with `issuer` and `jwksUri`, and that `issuer` is compared to the `iss` claim as an exact string.
- Why a `RequestAuthentication` alone leaves a workload unprotected, and how `requestPrincipals` in an `AuthorizationPolicy` makes a token mandatory.
- The request principal form `<issuer>/<subject>`, and `["*"]` for any valid token.
- `401` versus `403` here: which object produced each, and which fix each points at.
- The request attributes a validated token exposes — `request.auth.principal`, `request.auth.audiences`, `request.auth.claims[...]`.
- `when` conditions: values inside one entry ORed, multiple entries ANDed, and a list claim matching if any element matches.
- That a missing claim never matches, so a `when` condition fails closed under `ALLOW` and open under `DENY`.
- Why every claim rule should also carry `requestPrincipals`, or a tokenless request can slip past it.

---

## The Learning Path

### 1. Authenticate End Users With JWT
*   **Module Reader:** **[Module 1: Authenticate End Users With JWT](./module-01/course.md)**
    Deep-dive parts, in reading order:
    1. [Two identities on one request](./module-01/course-01-two-identities-and-the-filter.md)
    2. [`RequestAuthentication` and the key set](./module-01/course-02-requestauthentication-and-jwks.md)
    3. [Requiring a token](./module-01/course-03-requiring-a-token.md)
*   **Hands-on Playground:** `sections/section-030/module-01/playground` — namespace `jwt-demo` with no security objects at all, so you can watch a tokenless request succeed before and after each object is added.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-030/module-01/playground
    ```
*   **Graded lab:** **[Require A Valid End-User Token](./module-01/labs/lab-01/)** — read the
    [exam question](./module-01/labs/lab-01/docs/exam-question.md), solve it, then
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-030/module-01/labs/lab-01
    astrona submit -c .
    ```

### 2. Authorize On JWT Claims
*   **Module Reader:** **[Module 2: Authorize On JWT Claims](./module-02/course.md)**
    Deep-dive parts, in reading order:
    1. [Claims as request attributes](./module-02/course-01-claims-as-attributes.md)
    2. [`when` conditions and how they match](./module-02/course-02-when-conditions.md)
    3. [Designing and debugging claim rules](./module-02/course-03-designing-and-debugging.md)
*   **Hands-on Playground:** `sections/section-030/module-02/playground` — namespace `jwtclaims-demo` with the `RequestAuthentication` already applied as a precondition, so the module starts where the previous one ended.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-030/module-02/playground
    ```
*   **Graded lab:** **[Authorize On A JWT Claim](./module-02/labs/lab-01/)** — read the
    [exam question](./module-02/labs/lab-01/docs/exam-question.md), solve it, then
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-030/module-02/labs/lab-01
    astrona submit -c .
    ```

**Both playgrounds need outbound internet.** They use Istio's published demo tokens and the matching JWKS endpoint on `raw.githubusercontent.com`: you fetch the tokens, the proxy fetches the keys. Without outbound access you will see key-fetch failures rather than the behaviour the modules describe.

Each playground is ungraded: it spins up, prepares the environment, and waits. There is no task and no `astrona submit`. Tear one down with `astrona destroy <name>` when you are finished — the name is printed in each module's playground callout.

---

## Capstone

**[End-User Authentication Capstone](./capstone/labs/lab-01/)** — Validate tokens, require them, and split access by claim — with the workload identity rule still in force underneath.

Work it after every module in this section, without looking at the
walkthrough. It is graded the same way the module labs are.

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-030/capstone/labs/lab-01
astrona submit -c .
```
