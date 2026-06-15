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
| 1 | The Silent Node | `Pending` — zombie pods exhausting memory requests |
| 2 | The Ghost Image | `ImagePullBackOff` — wrong image tag in registry |
| 3 | The Infinite Scream | `CrashLoopBackOff` — missing environment variable |
| 4 | Death by a Thousand Requests | `OOMKilled` — memory limit too low |
| 5 | The Invisible Wall | `NetworkPolicy` blocking inter-pod communication |
| 6 | The Hoarder | node disk full — `kubelet` evicts pods |
| 7 | The Overzealous Guard | liveness probe too aggressive — killing healthy pods during startup |
| 8 | The Unclaimed Luggage | `PVC` references a non-existent `StorageClass` |
| 9 | The Deaf Service | service selector doesn't match pod labels |
| 10 | The Termination That Never Ends | app ignores `SIGTERM` — shell PID 1 doesn't forward signals |
| 11 | The DNS Ghost | `CoreDNS` pod crash — cluster DNS broken |
| 12 | The Forbidden Zone | `RBAC` — `ServiceAccount` missing API permissions |
| 13 | The Tainted Ground | node taint with no matching pod toleration |
| 14 | The Wrong Neighborhood | missing `nodeAffinity` — pod lands on wrong node type |
| 15 | The Thundering Herd | `HPA` not scaling — `metrics-server` not installed |
| 16 | The Unresponsive Witness | readiness probe returns 200 before app is actually ready |
| 17 | The Forgotten Namespace | `Secret` exists in wrong namespace — cross-namespace not allowed |
| 18 | The Broken Ladder | init container waiting on a service that doesn't exist yet |
| 19 | The Lying Clock | expired TLS certificate in `Secret` — HTTPS rejected |
| 20 | The Quota Prison | `ResourceQuota` exhausted — no new pods can be created |
| 21 | The Missing Brain | `kube-scheduler` crash — all pods stuck `Pending` |
| 22 | The Haunted ConfigMap | `ConfigMap` read at startup only — mounted volume not reloaded |
| 23 | The Pod That Ate the World | noisy neighbour consuming all node CPU — throttling other pods |
| 24 | The Vanishing Act | `PriorityClass` preemption — pod evicted silently |
| 25 | The Slow Drain | missing `preStop` hook — load balancer sends traffic to terminating pods |
| 26 | The Phantom Port | service `targetPort` doesn't match the container's actual port |
| 27 | The Sleeping Giant | cluster autoscaler not scaling up — missing IAM permissions |
| 28 | The Eternal Job | `CronJob` with no `concurrencyPolicy` — overlapping runs pile up |
| 29 | The Broken Bridge | Ingress controller not installed — Ingress resources ignored |
| 30 | The Headless Stalker | headless service misconfigured — `StatefulSet` pods can't find each other |
| 31 | The Stuck Upgrade | `maxUnavailable: 0` + single replica — rolling update deadlock |
| 32 | The Expired Token | `imagePullSecret` expired — registry credentials not rotated |
| 33 | The Jealous Node | pod anti-affinity prevents spreading — all replicas on one node |
| 34 | The Leaking Pipe | database connection leak — DB refuses new connections |
| 35 | The Misaligned Clock | node clock drift — JWT tokens fail validation |
| 36 | The Runaway Train | wrong `kubectl` context — command ran against wrong cluster |
| 37 | The Silent Sidecar | Istio sidecar injected on one side only — mTLS handshake fails |
| 38 | The Forbidden Fruit | `PodSecurityPolicy` blocks a privileged DaemonSet |
| 39 | The Phantom Service Account | pod references a non-existent `ServiceAccount` |
| 40 | The Persistent Ghost | `PVC` stuck `Terminating` — finalizer holds a pod reference |
| 41 | The Port Forward Impostor | overlapping label selectors — wrong pod served |
| 42 | The Inode Famine | inode exhaustion — disk has space but can't create files |
| 43 | The Invisible ConfigMap | `ConfigMap` with `subPath` mount — updates never propagated |
| 44 | The Starving Job | `Job` requests more CPU than any node can provide — never schedules |
| 45 | The Webhook Trap | `ValidatingWebhook` with `failurePolicy: Fail` — broken webhook blocks all pods |
| 46 | The Hungry Etcd | etcd disk too slow — high write latency causes API server timeouts |
| 47 | The Half-Open Door | `NodePort` reachable from some nodes only — `kube-proxy` not running |
| 48 | The Runaway Scaler | HPA receives 0 from dead metrics adapter — scales deployment to minimum |
| 49 | The Forgotten Finalizer | namespace stuck `Terminating` — resource with finalizer from deleted CRD |
| 50 | The Midnight Rollback | `revisionHistoryLimit: 0` — no rollback available after bad deploy |
| 51 | The Split Brain | etcd quorum lost after node failure — API server read-only |
| 52 | The Frozen Drain | `PodDisruptionBudget` blocks node drain — maintenance impossible |
| 53 | The Vertical Paradox | VPA and HPA conflict on same deployment — resource thrashing |
| 54 | The Locked Door | wrong `fsGroup` — volume owned by root, container runs as non-root |
| 55 | The Invisible Egress | `NetworkPolicy` egress rule missing — pod can't make outbound connections |
| 56 | The Phantom Scraper | Prometheus scraping wrong port — metrics endpoint not collected |
| 57 | The Poisoned Well | `NodeLocal DNSCache` stale records — service unreachable by name |
| 58 | The Velvet Eviction | Velero backup failing silently — no alerts on backup status |
| 59 | The Gateway Conflict | Ingress and Gateway API resources conflict — unpredictable routing |
| 60 | The Race in the Dark | two containers writing to shared `emptyDir` without coordination |
| 61 | The Operator Storm | operator reconciliation loop triggered by its own changes — infinite reconcile |
| 62 | The LimitRange Trap | `LimitRange` sets defaults — pod request exceeds `LimitRange` maximum |
| 63 | The Flapping Autoscaler | HPA scale-down too aggressive — no stabilization window configured |
| 64 | The Exhausted Job | `Job` `backoffLimit` exhausted — marked Failed silently, no alert |
| 65 | The New Node's Rejection | `DaemonSet` missing toleration — doesn't schedule on new tainted nodes |
| 66 | The Topology Straitjacket | `TopologySpreadConstraints` too strict — pod unschedulable |
| 67 | The External Record That Never Changes | `ExternalDNS` not updating — missing annotation on Service |
| 68 | The KEDA Ghost | `ScaledObject` points to deleted queue — workload scales to 0 |
| 69 | The Kubelet's Expiration | kubelet certificate expired — node goes `NotReady`, pods evicted |
| 70 | The CNI Collapse | Calico/Cilium node agent crash — pod networking broken on one node |
| 71 | The Helm Freeze | Helm upgrade fails — immutable field change in resource |
| 72 | The ArgoCD Loop | ArgoCD self-heal loop — dynamic fields cause perpetual drift |
| 73 | The Secret Leak | secrets encryption at rest not configured — etcd contains plaintext |
| 74 | The Audit Flood | audit logging at max verbosity — API server disk fills with requests |
| 75 | The Cert-Manager Silence | cert-manager issues cert to wrong `Secret` name — Ingress TLS broken |
| 76 | The Topology Mismatch | service topology routing misconfigured — cross-zone traffic misdirected |
| 77 | The Sidecar Dependency | main container starts before sidecar is ready — startup race |
| 78 | The Secret Store Timeout | External Secrets can't reach Vault — `NetworkPolicy` blocks egress |
| 79 | The Mutating Ghost | `MutatingWebhook` silently modifies pod specs — unexpected configuration |
| 80 | The ReadinessGate | `ReadinessGate` condition never set — pod never becomes Ready |
| 81 | The Sleeping Cron | `CronJob` `startingDeadlineSeconds` too short — job misses its window |
| 82 | The Miscounted Budget | `PodDisruptionBudget` misconfigured — blocks rolling update |
| 83 | The Orphaned Object | orphaned `ReplicaSet` with stale `ownerReference` — garbage collection stalled |
| 84 | The Certificate Authority Chain | webhook self-signed cert — cluster components can't verify it |
| 85 | The Node Lease Expiration | delayed node heartbeat — false `NotReady`, live node's pods evicted |
| 86 | The Projected Volume | projected `ServiceAccount` token short expiry — pods fail to authenticate |
| 87 | The Broken Webhook Server | webhook cert missing SAN for Kubernetes service DNS name |
| 88 | The Silent Drain | bare pod (no owner) blocks node `drain` indefinitely |
| 89 | The Invisible Finalizer | `CRD` deletion blocked by existing Custom Resources in other namespaces |
| 90 | The Container Runtime Error | `RunContainerError` — filesystem or mount configuration error |
| 91 | The Node Pressure Cascade | memory pressure on one node cascades — evictions across the cluster |
| 92 | The Graceful Death That Wasn't | `Job` pod ignores `SIGTERM` — data pipeline produces corrupt output |
| 93 | The Sidecar Stampede | log shipper sidecar floods network — no rate limit configured |
| 94 | The Zombie Namespace | stale finalizers on multiple resources block namespace deletion |
| 95 | The Fluentd Memory Spiral | Fluentd DaemonSet with no memory limit — consumes all node memory |
| 96 | The Miscalibrated Liveness | liveness probe timeout too short — slow pod restarted unnecessarily |
| 97 | The Service Account Token Thief | `automountServiceAccountToken` not disabled — all pods get API access |
| 98 | The Phantom Port-Forward | `kubectl port-forward` used in production — single point of failure |
| 99 | The Cluster That Knew Too Much | app with hardcoded cluster URL — breaks on cluster migration |
| 100 | The Last Case | no runbook, no on-call, no ownership — the cluster fails and nobody knows |

---

## Reproducing the cases locally

Each episode will eventually ship with a companion **KIND (Kubernetes IN Docker) setup** — either raw YAML manifests or a Helm chart — so you can reproduce the broken cluster state on your own machine, walk through the investigation yourself, and apply the fix.

To use these when they arrive, you will need:

- [Docker](https://www.docker.com/)
- [KIND](https://kind.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/) *(for chart-based episodes)*

Each episode directory contains a companion YAML manifest to reproduce the broken cluster state.

---

## Contributing

Suggestions for real-world failure scenarios are welcome. Open an issue with a brief description of the incident pattern — `OOMKilled`, silent RBAC denials, DNS resolution failures, stuck `Terminating` namespaces, whatever broke your Friday — and it may become the next episode.

---

*Inspector Ahmed will return.*
