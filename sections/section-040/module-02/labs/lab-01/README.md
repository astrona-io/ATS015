# Require Client Certificates At The Edge

- **ID:** LAB015-040-02
- **Slug:** ats-015-lab-040-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona hands-on lab — graded

Build a three-key credential and configure a MUTUAL gateway that refuses any client without a certificate from your CA.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS015.git -c sections/section-040/module-02/labs/lab-01
astrona submit -c .
astrona destroy ats-015-lab-040-02
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-015-lab-040-02`), not the
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
