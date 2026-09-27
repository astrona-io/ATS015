# Ambient Authorization Capstone

- **ID:** CAP015-060
- **Slug:** ats-015-capstone-060
- **Author:** Paris Nakita Kejser
- **Type:** Astrona hands-on capstone lab — graded

Split one access requirement across the two ambient enforcement points, and prove which component holds which half.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-060/capstone/labs/lab-01
astrona submit -c .
astrona destroy ats-015-capstone-060
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-015-capstone-060`), not the
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
