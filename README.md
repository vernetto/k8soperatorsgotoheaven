# Kubernetes Operators Go to Heaven

> *"The working class goes to heaven — and so do the people who keep your clusters alive at 3 AM."*

---

## What is this?

**Kubernetes Operators Go to Heaven** is a crime-noir educational series about real-world Kubernetes failures.

Each episode follows **Inspector Ahmed**, a seasoned cluster detective who investigates production incidents with the methods of a hard-boiled noir sleuth: reading pod autopsies, chasing down missing ConfigMaps, questioning rogue network policies, and hunting the smoking gun buried deep in `kubectl describe` output.

The format is intentionally dramatic. Kubernetes failures *are* dramatic — at least to the people who get paged at 3 AM to fix them.

---

## Why this title?

The series started life as **"100 Shades of Kubernetes"** — a nod to the endless variety of ways a cluster can silently fall apart.

The title then became **"Kubernetes Operators Go to Heaven"**, inspired by the 1971 Italian film *La classe operaia va in paradiso* (*The Working Class Goes to Heaven*) by Elio Petri. In the film, a factory worker is ground down by the relentless rhythm of industrial labor — present in body, absent in soul.

The parallel is intentional. The people who maintain production infrastructure — the SREs, the DevOps engineers, the platform teams — live inside the same grind. Paged at night, blamed for outages they didn't cause, expected to understand systems that were never properly documented. They keep everything running. They rarely get credited when it works. This series is, in a small way, for them.

---

## How it was made

The episodes are generated with the assistance of **Claude** (Anthropic's AI), working from real Kubernetes failure patterns and diagnostic workflows. The narrative structure, technical accuracy, and editorial choices are human-directed; the writing is AI-assisted.

This is an experiment in using fiction as a teaching vehicle for infrastructure concepts that are often dry on paper but genuinely interesting when you follow the trail of evidence to a root cause.

---

## Episodes

| # | Title | Diagnostic Focus |
|---|-------|-----------------|
| 1 | The Case of the Silent Pod | `CrashLoopBackOff` — missing ConfigMap |
| … | *more coming* | … |

---

## Reproducing the cases locally

Each episode will eventually ship with a companion **KIND (Kubernetes IN Docker) setup** — either raw YAML manifests or a Helm chart — so you can reproduce the broken cluster state on your own machine, walk through the investigation yourself, and apply the fix.

To use these when they arrive, you will need:

- [Docker](https://www.docker.com/)
- [KIND](https://kind.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/) *(for chart-based episodes)*

The companion manifests are not yet available. They will be added episode by episode.

---

## Contributing

Suggestions for real-world failure scenarios are welcome. Open an issue with a brief description of the incident pattern — `OOMKilled`, silent RBAC denials, DNS resolution failures, stuck `Terminating` namespaces, whatever broke your Friday — and it may become the next episode.

---

*Inspector Ahmed will return.*
