# 100 Shades of Kubernetes

*A noir detective course in 100 production incidents.*

---

## What is this?

**Inspector Ahmed** investigates production emergencies.

Each episode is a real Kubernetes failure mode — told as a noir detective story. Ahmed arrives at a broken cluster, reads the evidence, follows the trail, and makes an arrest. Along the way, you learn exactly what happened, why it happens, how to diagnose it, and how to fix it.

100 episodes. 100 different culprits. One detective.

---

## Who is this for?

- Developers deploying their first production workloads on Kubernetes
- Platform engineers who want a structured reference for production incidents
- SREs building runbooks and training material
- Anyone who has typed `kubectl describe pod` and wondered what the Events are telling them

---

## Structure of each episode

Every episode follows the same format:

```
OPENING       — The crime scene. What's broken, what it looks like.
ACT I         — First evidence. What the commands reveal.
ACT II        — Deeper investigation. Finding the root cause.
ACT III       — The fix (when needed).
THE ARREST    — Summary: what happened, why, how to resolve.
EPILOGUE      — Inspector Ahmed's closing rule.
TAKEAWAYS     — Command reference table.
```

---

## Episode Index

### Beginner (⭐)
| # | Title | Culprit |
|---|-------|---------|
| 1 | [The Silent Node](episode-01-the-silent-node.md) | Zombie pods exhausting memory requests |
| 2 | [The Ghost Image](episode-02-the-ghost-image.md) | Wrong image tag → ImagePullBackOff |
| 3 | [The Infinite Scream](episode-03-the-infinite-scream.md) | Missing Secret → CrashLoopBackOff |
| 4 | [Death by a Thousand Requests](episode-04-death-by-a-thousand-requests.md) | Memory limit too low → OOMKilled |
| 9 | [The Deaf Service](episode-09-the-deaf-service.md) | Service selector label mismatch |
| 17 | [The Forgotten Namespace](episode-17-the-forgotten-namespace.md) | Secret in wrong namespace |
| 26 | [The Phantom Port](episode-26-the-phantom-port.md) | Wrong Service targetPort |
| 36 | [The Runaway Train](episode-36-the-runaway-train.md) | Wrong kubectl context → accidental delete |
| 39 | [The Phantom Service Account](episode-39-the-phantom-service-account.md) | Non-existent ServiceAccount |
| 90 | [The Container Runtime Error](episode-90-the-container-runtime-error.md) | Missing Secret/ConfigMap at pod start |
| 98 | [The Phantom Port-Forward](episode-98-the-phantom-port-forward.md) | kubectl port-forward in production |

### Intermediate (⭐⭐)
| # | Title | Culprit |
|---|-------|---------|
| 5 | [The Invisible Wall](episode-05-the-invisible-wall.md) | NetworkPolicy deny-all |
| 6 | [The Hoarder](episode-06-the-hoarder.md) | Node disk full → evictions |
| 7 | [The Overzealous Guard](episode-07-the-overzealous-guard.md) | Liveness probe too aggressive |
| 8 | [The Unclaimed Luggage](episode-08-the-unclaimed-luggage.md) | Missing StorageClass |
| 10 | [The Termination That Never Ends](episode-10-the-termination-that-never-ends.md) | Shell PID1 ignores SIGTERM |
| 11 | [The DNS Ghost](episode-11-the-dns-ghost.md) | CoreDNS proxy loop |
| 12 | [The Forbidden Zone](episode-12-the-forbidden-zone.md) | RBAC missing permissions |
| 13 | [The Tainted Ground](episode-13-the-tainted-ground.md) | Node taint, no toleration |
| 14 | [The Wrong Neighborhood](episode-14-the-wrong-neighborhood.md) | No nodeAffinity → pod on spot instance |
| 15 | [The Thundering Herd](episode-15-the-thundering-herd.md) | HPA `<unknown>` — no metrics-server |
| 16 | [The Unresponsive Witness](episode-16-the-unresponsive-witness.md) | Readiness probe lying |
| 18 | [The Broken Ladder](episode-18-the-broken-ladder.md) | Init container waiting forever |
| 19 | [The Lying Clock](episode-19-the-lying-clock.md) | Expired TLS certificate |
| 20 | [The Quota Prison](episode-20-the-quota-prison.md) | ResourceQuota exhausted |
| 22 | [The Haunted ConfigMap](episode-22-the-haunted-configmap.md) | ConfigMap update not picked up |
| 23 | [The Pod That Ate the World](episode-23-the-pod-that-ate-the-world.md) | No CPU limit → noisy neighbour |
| 28 | [The Eternal Job](episode-28-the-eternal-job.md) | CronJob overlapping runs |
| 29 | [The Broken Bridge](episode-29-the-broken-bridge.md) | No Ingress controller installed |
| 31 | [The Stuck Upgrade](episode-31-the-stuck-upgrade.md) | maxSurge:0 + maxUnavailable:0 deadlock |
| 32 | [The Expired Token](episode-32-the-expired-token.md) | imagePullSecret expired |
| 33 | [The Jealous Node](episode-33-the-jealous-node.md) | No podAntiAffinity → all on one node |
| 35 | [The Misaligned Clock](episode-35-the-misaligned-clock.md) | Node clock drift → JWT expired |
| 40 | [The Persistent Ghost](episode-40-the-persistent-ghost.md) | PVC stuck Terminating |
| 41 | [The Port Forward Impostor](episode-41-the-port-forward-impostor.md) | Overlapping Service selectors |
| 43 | [The Invisible ConfigMap](episode-43-the-invisible-configmap.md) | subPath mount never updates |
| 44 | [The Starving Job](episode-44-the-starving-job.md) | Job requests exceed node capacity |
| 47 | [The Half-Open Door](episode-47-the-half-open-door.md) | kube-proxy crashed on node |
| 50 | [The Midnight Rollback](episode-50-the-midnight-rollback.md) | revisionHistoryLimit: 0 |
| 52 | [The Frozen Drain](episode-52-the-frozen-drain.md) | PDB blocks node drain |
| 54 | [The Locked Door](episode-54-the-locked-door.md) | Wrong fsGroup → permission denied |
| 55 | [The Invisible Egress](episode-55-the-invisible-egress.md) | Missing egress NetworkPolicy |
| 56 | [The Phantom Scraper](episode-56-the-phantom-scraper.md) | Wrong Prometheus scrape port |
| 62 | [The LimitRange Trap](episode-62-the-limitrange-trap.md) | LimitRange blocks pod creation |
| 63 | [The Flapping Autoscaler](episode-63-the-flapping-autoscaler.md) | HPA scaling up/down rapidly |
| 64 | [The Exhausted Job](episode-64-the-exhausted-job.md) | Job backoffLimit silently exhausted |
| 65 | [The New Node's Rejection](episode-65-the-new-nodes-rejection.md) | DaemonSet missing on new node |
| 67 | [The External Record That Never Changes](episode-67-the-external-record-that-never-changes.md) | ExternalDNS missing annotation |
| 71 | [The Helm Freeze](episode-71-the-helm-freeze.md) | Helm upgrade immutable field |
| 75 | [The Cert-Manager Silence](episode-75-the-cert-manager-silence.md) | cert-manager secretName mismatch |
| 81 | [The Sleeping Cron](episode-81-the-sleeping-cron.md) | CronJob missed schedule |
| 82 | [The Miscounted Budget](episode-82-the-miscounted-budget.md) | PDB blocks rolling update |
| 88 | [The Silent Drain](episode-88-the-silent-drain.md) | Bare pod blocks drain |
| 89 | [The Invisible Finalizer](episode-89-the-invisible-finalizer.md) | CRD blocked by existing CRs |
| 92 | [The Graceful Death That Wasn't](episode-92-the-graceful-death-that-wasnt.md) | Batch job not handling SIGTERM |
| 93 | [The Sidecar Stampede](episode-93-the-sidecar-stampede.md) | Log shipper floods network |
| 95 | [The Fluentd Memory Spiral](episode-95-the-fluentd-memory-spiral.md) | DaemonSet no memory limits |
| 96 | [The Miscalibrated Liveness](episode-96-the-miscalibrated-liveness.md) | Liveness timeout too short under load |
| 99 | [The Cluster That Knew Too Much](episode-99-the-cluster-that-knew-too-much.md) | Hardcoded API server URL |

### Advanced (⭐⭐⭐)
| # | Title | Culprit |
|---|-------|---------|
| 21 | [The Missing Brain](episode-21-the-missing-brain.md) | kube-scheduler crashed |
| 24 | [The Vanishing Act](episode-24-the-vanishing-act.md) | Pod preemption |
| 25 | [The Slow Drain](episode-25-the-slow-drain.md) | No preStop hook → 502s on deploy |
| 27 | [The Sleeping Giant](episode-27-the-sleeping-giant.md) | Cluster autoscaler IAM missing |
| 30 | [The Headless Stalker](episode-30-the-headless-stalker.md) | StatefulSet service not headless |
| 34 | [The Leaking Pipe](episode-34-the-leaking-pipe.md) | DB connection leak |
| 37 | [The Silent Sidecar](episode-37-the-silent-sidecar.md) | Istio sidecar missing → mTLS failure |
| 38 | [The Forbidden Fruit](episode-38-the-forbidden-fruit.md) | Pod Security Admission blocking DaemonSet |
| 42 | [The Inode Famine](episode-42-the-inode-famine.md) | Inode exhaustion |
| 45 | [The Webhook Trap](episode-45-the-webhook-trap.md) | ValidatingWebhook failurePolicy:Fail dead service |
| 48 | [The Runaway Scaler](episode-48-the-runaway-scaler.md) | Custom metrics adapter dead → HPA scales to 0 |
| 49 | [The Forgotten Finalizer](episode-49-the-forgotten-finalizer.md) | Namespace stuck Terminating |
| 53 | [The Vertical Paradox](episode-53-the-vertical-paradox.md) | VPA + HPA conflict |
| 57 | [The Poisoned Well](episode-57-the-poisoned-well.md) | NodeLocal DNS cache stale |
| 58 | [The Velvet Eviction](episode-58-the-velvet-eviction.md) | Velero backups silently failing |
| 59 | [The Gateway Conflict](episode-59-the-gateway-conflict.md) | Ingress + HTTPRoute claiming same host |
| 60 | [The Race in the Dark](episode-60-the-race-in-the-dark.md) | Shared volume race condition |
| 61 | [The Operator Storm](episode-61-the-operator-storm.md) | Infinite reconciliation loop |
| 66 | [The Topology Straitjacket](episode-66-the-topology-straitjacket.md) | TopologySpreadConstraints unsatisfiable |
| 68 | [The KEDA Ghost](episode-68-the-keda-ghost.md) | KEDA scaler dead event source |
| 69 | [The Kubelet's Expiration](episode-69-the-kubelets-expiration.md) | Kubelet certificate expired |
| 70 | [The CNI Collapse](episode-70-the-cni-collapse.md) | CNI plugin crash |
| 72 | [The ArgoCD Loop](episode-72-the-argocd-loop.md) | Perpetual OutOfSync from runtime annotations |
| 73 | [The Secret Leak](episode-73-the-secret-leak.md) | Secrets not encrypted at rest |
| 74 | [The Audit Flood](episode-74-the-audit-flood.md) | Audit logging too verbose |
| 76 | [The Topology Mismatch](episode-76-the-topology-mismatch.md) | Cross-zone routing causing latency |
| 77 | [The Sidecar Dependency](episode-77-the-sidecar-dependency.md) | App starts before sidecar ready |
| 78 | [The Secret Store Timeout](episode-78-the-secret-store-timeout.md) | External Secrets can't reach Vault |
| 79 | [The Mutating Ghost](episode-79-the-mutating-ghost.md) | MutatingWebhook adding blocking annotations |
| 80 | [The ReadinessGate](episode-80-the-readinessgate.md) | ReadinessGate condition never set |
| 83 | [The Orphaned Object](episode-83-the-orphaned-object.md) | Resource keeps reappearing |
| 84 | [The Certificate Authority Chain](episode-84-the-certificate-authority-chain.md) | Webhook missing caBundle |
| 85 | [The Node Lease Expiration](episode-85-the-node-lease-expiration.md) | Node declared dead due to network partition |
| 86 | [The Projected Volume](episode-86-the-projected-volume.md) | Cached ServiceAccount token expired |
| 87 | [The Broken Webhook Server](episode-87-the-broken-webhook-server.md) | Webhook cert missing SAN forms |
| 91 | [The Node Pressure Cascade](episode-91-the-node-pressure-cascade.md) | BestEffort pod triggers cluster-wide evictions |
| 94 | [The Zombie Namespace](episode-94-the-zombie-namespace.md) | Multiple resources with orphaned finalizers |
| 97 | [The Service Account Token Thief](episode-97-the-service-account-token-thief.md) | automountServiceAccountToken not disabled |

### Expert (⭐⭐⭐⭐)
| # | Title | Culprit |
|---|-------|---------|
| 46 | [The Hungry Etcd](episode-46-the-hungry-etcd.md) | etcd on slow disk |
| 51 | [The Split Brain](episode-51-the-split-brain.md) | etcd quorum loss |
| 100 | [The Last Case](episode-100-the-last-case.md) | No runbook, no owner, no on-call |

---

## The Most Important Commands

```bash
# Episode 0 — Before anything else
kubectl config current-context          # Are you on the right cluster?
kubectl get pods -n <namespace>         # What's the status?
kubectl describe pod <name> -n <ns>     # What do the Events say?
kubectl logs <pod> -n <ns> --previous   # What did the app say before dying?

# Resources
kubectl top pods --sort-by=memory       # Who is eating memory?
kubectl top pods --sort-by=cpu          # Who is eating CPU?
kubectl describe node <node>            # What's allocated on this node?
kubectl get endpoints <svc>             # Does this service have any pods?

# Networking
kubectl get networkpolicy -n <ns>       # Is anything blocked?
kubectl exec <pod> -- curl <svc>        # Can this pod reach that service?

# Storage
df -h / (on node)                       # Is disk full?
df -i / (on node)                       # Are inodes full?

# Control plane
kubectl get pods -n kube-system         # Is the control plane healthy?
kubectl auth can-i <verb> <resource> --as=<sa>   # Does this SA have permission?
```

---

## Contributing

Each episode is a self-contained Markdown file. To add an episode:

1. Follow the established format (OPENING → ACTs → EPILOGUE → Takeaways)
2. Name the file `episode-NNN-kebab-case-title.md`
3. Include the frontmatter: Culprit, Difficulty, Tags
4. End with Inspector Ahmed's numbered Rule

---

*"The cluster never lies. Read the Events."*

— Inspector Ahmed
