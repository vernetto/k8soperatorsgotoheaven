# Episode 88 — "The Silent Drain"
### *Inspector Ahmed and the node that drains but never finishes*

**Culprit:** Pod with no owner (bare pod) blocks drain indefinitely
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `drain` `bare-pods` `maintenance` `eviction`

---

## OPENING — Crime scene

"Node drain had been running for 45 minutes. Most pods had been rescheduled. But one pod — a bare pod, not owned by any controller — was refusing to leave. The drain command was stuck waiting for it."

```bash
kubectl drain node-2 --ignore-daemonsets --delete-emptydir-data
```

```
evicting pod production/api-7f9d4b-xk2p
evicting pod production/api-7f9d4b-r8tn
evicting pod production/debug-pod-manual     ← stuck here
```

```bash
kubectl get pod debug-pod-manual -n production
```

```
NAME               READY   STATUS    RESTARTS   AGE
debug-pod-manual   1/1     Running   0          5d
```

A pod called `debug-pod-manual`. 5 days old.

---

## ACT I — The bare pod

```bash
kubectl get pod debug-pod-manual -n production -o yaml | grep ownerReferences
```

```
(no output)
```

No `ownerReferences`. This is a **bare pod** — created directly with `kubectl run` or `kubectl apply`, not managed by a Deployment, StatefulSet, or Job.

When you evict a pod owned by a controller, the controller immediately creates a replacement. But a bare pod has no controller to recreate it — so `kubectl drain` by default refuses to evict it (because eviction would mean permanent loss).

> **📚 Teaching moment — Bare pods and drain**
>
> `kubectl drain` can evict:
> - Pods managed by ReplicaSets, Deployments, DaemonSets (with `--ignore-daemonsets`), StatefulSets, Jobs
>
> `kubectl drain` by default **refuses** to evict:
> - Bare pods (no owner) — would be permanently deleted
> - Pods with local storage (emptyDir) — would lose data, unless `--delete-emptydir-data` is passed
>
> The `--force` flag overrides this protection and deletes bare pods. Use with caution — the pod is gone for good.
>
> **Best practice**: never create bare pods in production. Always use a controller.

---

## ACT II — Handling the bare pod

```bash
# Check if this pod is important
kubectl describe pod debug-pod-manual -n production
```

```
Annotations: created-by: sarah@company.com
             purpose: debugging incident INC-4821 (RESOLVED)
```

It's a leftover debug pod from a resolved incident 5 days ago. Safe to delete.

```bash
kubectl delete pod debug-pod-manual -n production
```

With the bare pod gone, drain completes:

```bash
kubectl drain node-2 --ignore-daemonsets --delete-emptydir-data
```

```
node/node-2 drained
```

---

## EPILOGUE

*"kubectl drain refuses to evict bare pods. They have no controller to recreate them — eviction is permanent. Always check what the bare pod is before using --force. In production, bare pods are almost always debugging leftovers. Delete them when the incident is resolved."*

> **Inspector Ahmed's Rule #88:** `kubectl drain` stuck on a pod? Check if it has no ownerReferences (bare pod). Identify its purpose. If safe to delete, delete it manually. Never create bare pods in production — always use a controller.
