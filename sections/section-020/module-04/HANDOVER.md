# Module 020-04 hand-over (UNTESTED)

Written from the Istio external authorization task, the AuthorizationPolicy reference and the MeshConfig reference. Nothing was run on a cluster.

Open assumptions to check on a cluster:

- Mesh configuration changes in the `istio` ConfigMap reach the proxies within about a minute without restarting istiod (the lab and parts wait and retry).
- `course-02`: exact body of a denial from the sample authorizer, and the `X-Ext-Authz-Check-Result: allowed` response header.
- `course-03`: an authorizer allow followed by a DENY still reaches the authorizer log; the `fortio load -H` helper prints `Code 403`.
- `course-03`: with the authorizer scaled to 0, a matched request returns 403 (default failOpen false, statusOnError 403).
- Lab 01: the grader's "other settings still present" grep (accessLogFile, defaultConfig, enablePrometheusMerge, trustDomain) matches the mesh config written by `istioctl install --set profile=demo`.
- Lab 01: `jq` is available on the student's machine.
