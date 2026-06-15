# 100 Shades of Kubernetes — Hands-On Lab Manifests

> *Inspector Ahmed investigated 100 Kubernetes failures. Now it's your turn to solve them.*

Each episode in the [100 Shades of Kubernetes](https://github.com/vernetto/k8soperatorsgotoheaven/tree/main/100-shades-of-kubernetes) noir detective series has a corresponding YAML manifest here. Apply it to a KIND cluster, reproduce the exact starting situation from the episode, and try to fix it yourself — before reading the solution.

---

## Prerequisites

- [KIND](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) v0.20+
- [kubectl](https://kubernetes.io/docs/tasks/tools/) v1.28+
- [Docker](https://docs.docker.com/get-docker/) (or Podman)

---

## Quick Start

### 1. Create the lab cluster

```bash
kind create cluster --name k8s-shades --config kind-cluster.yaml
kubectl cluster-info --context kind-k8s-shades
```

The cluster has **1 control-plane + 2 worker nodes**, with zone labels pre-configured for topology-sensitive episodes.

### 2. Pick an episode and start the lab

```bash
# List all episodes
./setup.sh

# Set up episode 5 (The Invisible Wall — NetworkPolicy)
./setup.sh 5

# Investigate...
kubectl get pods -n production
kubectl exec -n production deploy/frontend -- curl http://backend

# Clean up when done
./setup.sh --teardown 5
```

### 3. Manual approach

```bash
kubectl apply -f episode-05-the-invisible-wall.yaml
# ... investigate, fix, verify ...
kubectl delete -f episode-05-the-invisible-wall.yaml
```

---

## Episode Index

| # | File | Culprit | Difficulty |
|---|------|---------|------------|
| 01 | episode-01-the-silent-node.yaml | Zombie pods exhausting memory requests → new pod Pending | ⭐ |
| 02 | episode-02-the-ghost-image.yaml | Wrong image tag → ImagePullBackOff | ⭐ |
| 03 | episode-03-the-infinite-scream.yaml | Missing env var → app crash → CrashLoopBackOff | ⭐ |
| 04 | episode-04-death-by-a-thousand-requests.yaml | Memory limit too low → OOMKilled (exit 137) | ⭐ |
| 05 | episode-05-the-invisible-wall.yaml | NetworkPolicy blocking inter-pod traffic | ⭐⭐ |
| 06 | episode-06-the-hoarder.yaml | Ephemeral storage limit exceeded → pod evicted | ⭐⭐ |
| 07 | episode-07-the-overzealous-guard.yaml | Liveness probe kills pod during slow startup | ⭐⭐ |
| 08 | episode-08-the-unclaimed-luggage.yaml | PVC references non-existent StorageClass → Pending | ⭐⭐ |
| 09 | episode-09-the-deaf-service.yaml | Service selector label mismatch → 0 endpoints | ⭐ |
| 10 | episode-10-the-termination-that-never-ends.yaml | Shell PID 1 doesn't forward SIGTERM → stuck Terminating | ⭐⭐ |
| 11 | episode-11-the-dns-ghost.yaml | CoreDNS down → all DNS resolution fails | ⭐⭐ |
| 12 | episode-12-the-forbidden-zone.yaml | ServiceAccount missing RBAC → 403 on API calls | ⭐⭐ |
| 13 | episode-13-the-tainted-ground.yaml | Node taint with no pod toleration → Pending | ⭐⭐ |
| 14 | episode-14-the-wrong-neighborhood.yaml | Missing nodeAffinity → stateful pod on spot node | ⭐⭐ |
| 15 | episode-15-the-thundering-herd.yaml | HPA shows `<unknown>` → metrics-server missing | ⭐⭐ |
| 16 | episode-16-the-unresponsive-witness.yaml | Readiness probe lies → 502s during rolling update | ⭐⭐⭐ |
| 17 | episode-17-the-forgotten-namespace.yaml | Secret in wrong namespace → pod can't start | ⭐ |
| 18 | episode-18-the-broken-ladder.yaml | Init container waits for non-existent service | ⭐⭐ |
| 19 | episode-19-the-lying-clock.yaml | Expired TLS certificate → HTTPS rejected | ⭐⭐ |
| 20 | episode-20-the-quota-prison.yaml | ResourceQuota exhausted → new pods blocked | ⭐⭐ |
| 21 | episode-21-the-missing-brain.yaml | kube-scheduler down → all new pods Pending | ⭐⭐⭐ |
| 22 | episode-22-the-haunted-configmap.yaml | App reads ConfigMap once at startup → stale config | ⭐⭐ |
| 23 | episode-23-the-pod-that-ate-the-world.yaml | Pod with no CPU limit starves its neighbours | ⭐⭐ |
| 24 | episode-24-the-vanishing-act.yaml | High-priority pod preempts lower-priority pods | ⭐⭐⭐ |
| 25 | episode-25-the-slow-drain.yaml | No preStop hook → 502s during rolling update | ⭐⭐⭐ |
| 26 | episode-26-the-phantom-port.yaml | Service targetPort wrong → connection refused | ⭐ |
| 27 | episode-27-the-sleeping-giant.yaml | Cluster autoscaler blocked by missing IAM | ⭐⭐⭐ |
| 28 | episode-28-the-eternal-job.yaml | CronJob with no concurrencyPolicy → overlapping runs | ⭐⭐ |
| 29 | episode-29-the-broken-bridge.yaml | Ingress controller not installed → 404 everywhere | ⭐⭐ |
| 30 | episode-30-the-headless-stalker.yaml | StatefulSet service not headless → pods can't find each other | ⭐⭐⭐ |
| 31 | episode-31-the-stuck-upgrade.yaml | maxSurge:0 + maxUnavailable:0 + 1 replica = deadlock | ⭐⭐ |
| 32 | episode-32-the-expired-token.yaml | imagePullSecret expired → ImagePullBackOff | ⭐⭐ |
| 33 | episode-33-the-jealous-node.yaml | No podAntiAffinity → all replicas on same node | ⭐⭐ |
| 34 | episode-34-the-leaking-pipe.yaml | DB connection leak → pool exhaustion | ⭐⭐⭐ |
| 35 | episode-35-the-misaligned-clock.yaml | Node clock drift → JWT always expired | ⭐⭐ |
| 36 | episode-36-the-runaway-train.yaml | Wrong kubectl context → command hits wrong cluster | ⭐ |
| 37 | episode-37-the-silent-sidecar.yaml | Istio sidecar on one side only → mTLS failure | ⭐⭐⭐ |
| 38 | episode-38-the-forbidden-fruit.yaml | PodSecurityAdmission blocks privileged DaemonSet | ⭐⭐⭐ |
| 39 | episode-39-the-phantom-service-account.yaml | Pod references non-existent ServiceAccount | ⭐ |
| 40 | episode-40-the-persistent-ghost.yaml | PVC stuck Terminating — pod still holds reference | ⭐⭐ |
| 41 | episode-41-the-port-forward-impostor.yaml | Overlapping service selectors → wrong pods get traffic | ⭐⭐ |
| 42 | episode-42-the-inode-famine.yaml | Inode exhaustion — disk has space but can't create files | ⭐⭐⭐ |
| 43 | episode-43-the-invisible-configmap.yaml | subPath mount never updates → stale config in pod | ⭐⭐⭐ |
| 44 | episode-44-the-starving-job.yaml | Job requests more CPU/RAM than any node has → Pending | ⭐⭐ |
| 45 | episode-45-the-webhook-trap.yaml | ValidatingWebhook with failurePolicy:Fail + dead service | ⭐⭐⭐ |
| 46 | episode-46-the-hungry-etcd.yaml | etcd on slow disk → API server timeouts | ⭐⭐⭐ |
| 47 | episode-47-the-half-open-door.yaml | kube-proxy crashed on one node → NodePort unreachable | ⭐⭐⭐ |
| 48 | episode-48-the-runaway-scaler.yaml | Custom metrics adapter down → HPA scales to 0 | ⭐⭐⭐ |
| 49 | episode-49-the-forgotten-finalizer.yaml | Namespace Terminating — CR finalizer from deleted CRD | ⭐⭐⭐ |
| 50 | episode-50-the-midnight-rollback.yaml | revisionHistoryLimit:0 → no rollback possible | ⭐⭐ |
| 51 | episode-51-the-split-brain.yaml | etcd loses quorum → API server read-only | ⭐⭐⭐⭐ |
| 52 | episode-52-the-frozen-drain.yaml | PDB minAvailable == replicas → drain impossible | ⭐⭐⭐ |
| 53 | episode-53-the-vertical-paradox.yaml | VPA + HPA on same deployment → thrashing | ⭐⭐⭐ |
| 54 | episode-54-the-locked-door.yaml | Missing fsGroup → non-root container can't write to volume | ⭐⭐ |
| 55 | episode-55-the-invisible-egress.yaml | Egress NetworkPolicy blocks outbound + DNS | ⭐⭐ |
| 56 | episode-56-the-phantom-scraper.yaml | Prometheus scraping wrong port → no metrics | ⭐⭐ |
| 57 | episode-57-the-poisoned-well.yaml | NodeLocal DNSCache stale entry → wrong IP | ⭐⭐⭐ |
| 58 | episode-58-the-velvet-eviction.yaml | Velero backups silently failing — no alert | ⭐⭐⭐ |
| 59 | episode-59-the-gateway-conflict.yaml | Ingress + HTTPRoute both claim same hostname | ⭐⭐⭐ |
| 60 | episode-60-the-race-in-the-dark.yaml | Two containers write shared volume without locking | ⭐⭐⭐ |
| 61 | episode-61-the-operator-storm.yaml | Non-idempotent operator reconcile → infinite CPU loop | ⭐⭐⭐ |
| 62 | episode-62-the-limitrange-trap.yaml | Pod request exceeds LimitRange maximum → rejected | ⭐⭐ |
| 63 | episode-63-the-flapping-autoscaler.yaml | HPA with no stabilizationWindow → rapid scale up/down | ⭐⭐ |
| 64 | episode-64-the-exhausted-job.yaml | Job backoffLimit exhausted → silently Failed | ⭐⭐ |
| 65 | episode-65-the-new-nodes-rejection.yaml | DaemonSet missing toleration → not on new node | ⭐⭐ |
| 66 | episode-66-the-topology-straitjacket.yaml | TopologySpreadConstraints too strict → pods Pending | ⭐⭐⭐ |
| 67 | episode-67-the-external-record-that-never-changes.yaml | ExternalDNS ignores Service — annotation missing | ⭐⭐ |
| 68 | episode-68-the-keda-ghost.yaml | KEDA ScaledObject points to deleted queue → scales to 0 | ⭐⭐⭐ |
| 69 | episode-69-the-kubelets-expiration.yaml | Kubelet cert expired → node NotReady → pod evictions | ⭐⭐⭐ |
| 70 | episode-70-the-cni-collapse.yaml | CNI agent crash → pods on that node lose networking | ⭐⭐⭐ |
| 71 | episode-71-the-helm-freeze.yaml | Helm upgrade changes immutable spec.selector → fails | ⭐⭐ |
| 72 | episode-72-the-argocd-loop.yaml | ArgoCD perpetually OutOfSync — runtime annotations | ⭐⭐⭐ |
| 73 | episode-73-the-secret-leak.yaml | etcd encryption at rest not configured → plaintext Secrets | ⭐⭐⭐ |
| 74 | episode-74-the-audit-flood.yaml | Audit logging at max verbosity → disk fills | ⭐⭐⭐ |
| 75 | episode-75-the-cert-manager-silence.yaml | cert-manager writes cert to wrong Secret name | ⭐⭐ |
| 76 | episode-76-the-topology-mismatch.yaml | Service routes cross-zone → latency + cost | ⭐⭐⭐ |
| 77 | episode-77-the-sidecar-dependency.yaml | App starts before sidecar proxy is ready → crash | ⭐⭐⭐ |
| 78 | episode-78-the-secret-store-timeout.yaml | NetworkPolicy blocks ESO → Vault unreachable | ⭐⭐⭐ |
| 79 | episode-79-the-mutating-ghost.yaml | MutatingWebhook injects bad nodeSelector → Pending | ⭐⭐⭐ |
| 80 | episode-80-the-readinessgate.yaml | ReadinessGate condition never set → pod never Ready | ⭐⭐⭐ |
| 81 | episode-81-the-sleeping-cron.yaml | startingDeadlineSeconds too short → CronJob skipped | ⭐⭐ |
| 82 | episode-82-the-miscounted-budget.yaml | PDB minAvailable == replicas → rolling update stalls | ⭐⭐ |
| 83 | episode-83-the-orphaned-object.yaml | Controller keeps recreating deleted resource | ⭐⭐ |
| 84 | episode-84-the-certificate-authority-chain.yaml | Webhook caBundle empty → TLS verify failure | ⭐⭐⭐ |
| 85 | episode-85-the-node-lease-expiration.yaml | Node heartbeat delayed → declared dead while alive | ⭐⭐⭐ |
| 86 | episode-86-the-projected-volume.yaml | Projected SA token short expiry → 401 after N minutes | ⭐⭐⭐ |
| 87 | episode-87-the-broken-webhook-server.yaml | Webhook cert missing SAN → TLS handshake fails | ⭐⭐⭐ |
| 88 | episode-88-the-silent-drain.yaml | Bare pod blocks kubectl drain | ⭐⭐ |
| 89 | episode-89-the-invisible-finalizer.yaml | CRD deletion blocked by CRs in other namespaces | ⭐⭐ |
| 90 | episode-90-the-container-runtime-error.yaml | Missing Secret → CreateContainerConfigError | ⭐⭐ |
| 91 | episode-91-the-node-pressure-cascade.yaml | BestEffort pod with no limits → memory pressure cascade | ⭐⭐⭐ |
| 92 | episode-92-the-graceful-death-that-wasnt.yaml | Job doesn't handle SIGTERM → corrupt output | ⭐⭐ |
| 93 | episode-93-the-sidecar-stampede.yaml | Log shipper sidecar with no rate limit → network flood | ⭐⭐ |
| 94 | episode-94-the-zombie-namespace.yaml | Stale finalizers → namespace stuck Terminating | ⭐⭐⭐ |
| 95 | episode-95-the-fluentd-memory-spiral.yaml | Fluentd DaemonSet with no memory limit → evictions | ⭐⭐ |
| 96 | episode-96-the-miscalibrated-liveness.yaml | Liveness probe timeout too short → kills pod under load | ⭐⭐ |
| 97 | episode-97-the-service-account-token-thief.yaml | automountServiceAccountToken not disabled → all pods get API | ⭐⭐⭐ |
| 98 | episode-98-the-phantom-port-forward.yaml | kubectl port-forward in production → SPOF | ⭐ |
| 99 | episode-99-the-cluster-that-knew-too-much.yaml | Hardcoded API server URL → breaks on migration | ⭐⭐ |
| 100 | — | No runbook, no on-call, no ownership. No YAML can fix this one. | ⭐⭐⭐⭐ |

---

## Manifest Structure

Every manifest file follows the same pattern:

```yaml
# Episode NN — "Title"
# Culprit: one-line description of the bug
# Setup: what this manifest creates

--- 
# (resources that set up the broken state)

# EXPECTED: what you should observe
# DIAGNOSE: kubectl commands to investigate
# FIX: how to resolve it
```

---

## Tips for Getting the Most from These Labs

1. **Read only the header comment** before applying — don't read the `FIX` section yet.
2. **Observe first**: `kubectl get pods`, `kubectl get events --sort-by=.lastTimestamp`
3. **Describe**: `kubectl describe pod <name>` — the Events section is almost always the first clue.
4. **Logs**: `kubectl logs <name>` and `kubectl logs <name> --previous` for crashed containers.
5. **Use `kubectl auth can-i`** for RBAC issues, `kubectl get endpoints` for Service issues.
6. **Check labels carefully** — many episodes hinge on a one-word label mismatch.

---

## Inspector Ahmed's Complete Rule Set

From Episode 100's epilogue — the full 100-rule reference card is in
`episode-100-the-last-case.md` in the original repository.

---

*"The Events were always there. Were you?"*
— Inspector Ahmed
