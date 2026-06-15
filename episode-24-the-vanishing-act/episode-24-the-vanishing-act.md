# Episode 24 — "The Vanishing Act"
### *Inspector Ahmed and the pod that disappears without a trace*

**Culprit:** Preemption — high-priority pod evicts lower-priority pods
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `priority` `preemption` `priorityclass` `scheduling`

---

## OPENING — Crime scene

"Pods were disappearing. Not crashing — just gone. No OOM. No eviction message. No error in the logs. They ran for a few minutes, then vanished. The audit log held the answer."

```bash
kubectl get pods -n batch-jobs
```

```
NAME                       READY   STATUS    RESTARTS   AGE
batch-worker-7f9d-xk2p     0/1     Pending   0          2m
```

Ahmed checks recent events:

```bash
kubectl get events -n batch-jobs --sort-by='.metadata.creationTimestamp' | tail -10
```

```
Warning  Preempting  2m  default-scheduler
  Preempted pod batch-worker-7f9d4b-r8tn1 on node node-2
  to make room for higher priority pod ml-training-9c2e1a-xr7wl
```

*Preemption.* A higher-priority pod requested resources, found no room, and the scheduler evicted a lower-priority pod to make space.

> **📚 Teaching moment — PriorityClass and Preemption**
>
> Kubernetes supports pod priority. A PriorityClass assigns a numeric priority to pods. When a high-priority pod can't be scheduled, the scheduler may **preempt** (evict) lower-priority pods to free up resources.
>
> Default PriorityClasses:
> - `system-cluster-critical` (2000000000) — for core cluster components
> - `system-node-critical` (2000001000) — for node-critical components
>
> Custom ones are created by the ops team. The problem here: an ML training job was given `high-priority` (1000) and batch workers weren't given any priority class (defaults to 0). ML training evicts batch workers whenever it needs resources.

---

## ACT II — Reviewing priority classes

```bash
kubectl get priorityclass
```

```
NAME                      VALUE        GLOBAL-DEFAULT
system-cluster-critical   2000000000   false
system-node-critical      2000001000   false
high-priority             1000         false
low-priority              100          false
```

```bash
kubectl get pod ml-training-9c2e1a-xr7wl -n ml-jobs -o yaml | grep priorityClassName
```

```
  priorityClassName: high-priority
```

The ML training job has `high-priority`. The batch workers have no priority class — they default to 0 and are easy targets for preemption.

Fix: assign `low-priority` to batch workers so they are explicit about their position in the hierarchy but document that they can be preempted:

```yaml
spec:
  priorityClassName: low-priority
```

Or, better: size the cluster so preemption isn't needed, or use separate node pools for ML and batch workloads.

---

## EPILOGUE

*"Preemption is a feature, not a bug. But it's only good if it's intentional. Assign PriorityClasses explicitly to every workload type. Never let pods default to priority 0 by accident."*

> **Inspector Ahmed's Rule #24:** Pods disappearing with no crash? Check `kubectl get events` for `Preempting` entries. Review PriorityClasses. Make priority explicit — never implicit.
