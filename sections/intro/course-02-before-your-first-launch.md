# Get Your Machine Ready

Every playground and lab in this course runs on your own machine, in a small Kubernetes cluster. A tool called `astrona` builds it for you, sets it up, grades your work and removes it again. This page gets your machine ready.

## What you need

These are the tools for every section, plus two extra needs for some of them.

### Tools for every section

- **A container engine:** Docker or Podman. The cluster runs inside it.
- **`kind`:** runs Kubernetes inside the container engine.
- **`kubectl`:** talks to the cluster.
- **`istioctl`:** Istio's own command-line tool. You use it in almost every module.
- **`helm`:** the playgrounds install Istio with it.
- **The astrona command-line tool.**
- **`jq`:** reads the JSON that `kubectl` and `istioctl` print, so you can pick out one field.
- **`openssl`:** reads the certificate each workload carries (the signed file that proves its identity), and makes test certificates for the sections on TLS at the edge. Most macOS and Linux machines already have it.

### Extra needs for some sections

- **Outbound internet:** the JWT section downloads demo tokens and their keys from `raw.githubusercontent.com`. The module that adds TLS to requests leaving the mesh calls `httpbin.org`. Without outbound internet, those steps fail with network errors that have nothing to do with Istio.

### Let astrona check your machine

Let `astrona` check the rest for you:

```sh
astrona setup
```

`astrona setup` looks at what is missing, shows you each step it would take, and asks before it does anything. On macOS it can install `kind`, `kubectl` and Podman. Install `istioctl` and `helm` yourself.

To check your machine at any time:

```sh
astrona check
```

## The commands you use every day

You need only a handful of `astrona` commands. Each module page and lab page shows the exact command to copy, so you do not need to remember paths.

### Sign in

Labs from the course catalog are tied to your Astrona account:

```sh
astrona login
```

### Start a playground or lab

Each module page and lab page shows the exact `astrona run` command for its playground or lab. It looks like this:

```sh
astrona run --git git@github.com:astrona-io/ATS015.git -c sections/section-010/module-01/playground
```

When the cluster is ready, `kubectl` already points at it.

### Pause and wake up a playground

When a part sends you to a lab, pause the playground first. Pausing frees your machine's memory but keeps everything you built:

```sh
astrona stop <name>
```

When the lab is done, wake the playground up again and carry on where you left off:

```sh
astrona start <name>
```

### Submit a lab for grading

The grader checks the live cluster. It sends real requests and reads the proxy's configuration, so your work has to actually work, not only exist. Each lab page shows the exact command:

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

You can submit as often as you like.

### Clean up

When you are done with a playground or a lab, remove it:

```sh
astrona destroy <name>
```

The name is the environment's name, printed by `astrona run` and shown on each page (for example `ats-015-playground-010-01`). It is not the folder path. To see what is on your machine:

```sh
astrona list
```

> [!WARNING]
> **Run one environment at a time.** Each playground and lab is a whole cluster. Two running at once slow your machine down, and it is easy to send a command to the wrong one. Pause or destroy the playground before you start the lab.

## When a start goes wrong

Ask `astrona` what is wrong before you try anything else:

```sh
astrona doctor
```

It checks your machine, the lab's configuration and the running lab, and tells you how to fix what it finds.

If a step that reaches the internet fails, check your network first. The page tells you when a step needs outbound internet.
