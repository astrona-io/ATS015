# Enforce mTLS With PeerAuthentication At Three Scopes (PLAYGROUND) — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-015-playground-010-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

Clean Istio sandbox for the module "Enforce mTLS With PeerAuthentication At Three Scopes".

A single sandbox environment that spins up, runs OS prep, and stays running so
you can explore the module's topic on a clean machine. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-015-playground-010-02
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-015-playground-010-02`), not
the config path. `astrona submit` and `astrona test` do not apply — there is no
grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime + bootstrap only) |
| `manifests/` | Manifests applied at bootstrap (namespace, workloads, and any preconditions) |
| `bootstrap/prepare.sh` | OS prep run once at startup |
| `docs/overview.md` | What the environment contains and ideas to try |
