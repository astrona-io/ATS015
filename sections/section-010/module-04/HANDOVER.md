# Module 010-04 hand-over (UNTESTED)

Written from the Istio plug-in CA task and the pilot-discovery and pilot-agent references. Nothing was run on a cluster.

Open assumptions to check on a cluster:

- The `openssl` command lines for the root, the intermediate and the extension files are not from the Istio docs (the docs use a Makefile). Check they work with the macOS LibreSSL and that Istio accepts the resulting intermediate.
- Restarting `istiod` on a running mesh picks up `cacerts` (the docs do not describe the restart).
- `SECRET_TTL` through the `proxy.istio.io/config` annotation with `proxyMetadata` gives the requested lifetime (not shown in the Istio docs; only in the references and third-party posts).
- `openssl s_client` inside the `istio-proxy` container reads the chain from a `STRICT` workload (this is the method of the Istio docs), and the first certificate is the workload certificate.
- `course-01`: `istio-ca-secret` and `istio-ca-root-cert` names; `openssl x509 -ext` needs OpenSSL 1.1.1+.
- Lab 01: `base64 -d` or `-D` on the grader machine; `openssl` on the grader machine.
- The `-checkend 14400` test for probe-long assumes a renewed 24h certificate has at least 12h left.
