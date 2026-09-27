# Migrate A Namespace To STRICT mTLS

- **ID:** LAB015-010-03
- **Slug:** ats-015-lab-010-03
- **Author:** Paris Nakita Kejser
- **Type:** Astrona hands-on lab — graded

Move the last plaintext caller into the mesh, then flip the namespace to STRICT without breaking it.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-010/module-03/labs/lab-01
astrona submit -c .
astrona destroy ats-015-lab-010-03
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-015-lab-010-03`), not the
config path.

## Prove it (authors / CI)

```sh
astrona test -c . --junit-xml=report.xml
```

`astrona test` bootstraps the lab, applies `solution/`, submits it, and tears down —
proving a learner who does everything right passes.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Lab definition (bootstrap / testing / validation / teardown) |
| `docs/prerequisites.md` | What to know and have installed first |
| `docs/exam-question.md` | The formal, self-contained task |
| `docs/case-study.md` | The same task as a scenario, with hints instead of an answer |
| `docs/step-by-step-guide.md` | Full walkthrough, including the answer |
| `manifests/` | Starting state applied at bootstrap |
| `bootstrap/setup.sh` | Istio install and pre-work — never the graded objects |
| `solution/` | Reference end state (CI only; learners do not see it during a run) |
| `validate.sh` | Behavioural grading |
| `teardown/dump-logs.sh` | State capture before teardown |
