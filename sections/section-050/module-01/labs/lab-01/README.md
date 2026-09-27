# Block A Client Range At The Gateway

- **ID:** LAB015-050-01
- **Slug:** ats-015-lab-050-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona hands-on lab — graded

Write a gateway-scoped AuthorizationPolicy that denies a forwarded client range without closing the rest of the edge.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-050/module-01/labs/lab-01
astrona submit -c .
astrona destroy ats-015-lab-050-01
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-015-lab-050-01`), not the
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
