# Episode 83 — "The Orphaned Object"
### *Inspector Ahmed and the resource that owns nothing but can't be deleted*

**Culprit:** Orphaned ReplicaSet with a stale ownerReference to a deleted Deployment — garbage collection stalled
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `ownerreference` `garbage-collection` `replicaset` `cleanup`

---

## OPENING — Crime scene

"The namespace was supposed to be clean. But `kubectl get all` kept showing old ReplicaSets — empty ones, with zero pods. They'd been there for weeks. Attempts to delete them failed. They kept coming back."

```bash
kubectl get replicasets -n production
```

```
NAME              DESIRED   CURRENT   READY   AGE
api-7f9d4b        0         0         0       90d
api-6d8f9c        0         0         0       85d
api-5c7b8a        3         3         3       2d     ← active
```

Two empty ReplicaSets lingering. Ahmed tries to delete them:

```bash
kubectl delete replicaset api-7f9d4b -n production
```

```
replicaset.apps "api-7f9d4b" deleted
```

```bash
kubectl get replicasets -n production
```

```
NAME              DESIRED   CURRENT   READY   AGE
api-7f9d4b        0         0         0       1s    ← back!
```

It was recreated immediately by something.

---

## ACT I — The ownerReference chain

```bash
kubectl get replicaset api-7f9d4b -n production -o yaml | grep -A 5 "ownerReferences:"
```

```yaml
ownerReferences:
- apiVersion: apps/v1
  kind: Deployment
  name: api-legacy
  uid: a3f8c12d-0000-0000-0000-000000000000
  controller: true
  blockOwnerDeletion: true
```

The ReplicaSet claims to be owned by `Deployment/api-legacy`. But:

```bash
kubectl get deployment api-legacy -n production
```

```
Error from server (NotFound): deployments.apps "api-legacy" not found
```

The deployment is gone — but the ReplicaSet's ownerReference still points to it. Kubernetes garbage collection normally works top-down (deleting owner deletes owned resources), but this reference is stale (the owner is gone). The ReplicaSet isn't being garbage collected because the UID in the reference no longer exists.

Why does it come back? Because there's a controller elsewhere that is mistakenly recreating it. Ahmed searches:

```bash
kubectl get pods -n operators | grep legacy-reconciler
```

```
legacy-reconciler-7f9d-xk2p   1/1   Running   0   30d
```

An old reconciler is recreating the ReplicaSet every time it's deleted. The reconciler needs to be decommissioned.

---

## ACT II — Cleaning up properly

```bash
# Stop the reconciler first
kubectl scale deployment legacy-reconciler --replicas=0 -n operators

# Remove the stale OwnerReference from the ReplicaSet
kubectl patch replicaset api-7f9d4b -n production \
  --type=json \
  -p='[{"op":"remove","path":"/metadata/ownerReferences"}]'

# Now delete
kubectl delete replicaset api-7f9d4b api-6d8f9c -n production
```

They stay deleted.

---

## EPILOGUE

*"A resource that keeps coming back after deletion has something recreating it. Find that something — a controller, an operator, a CronJob. Stop it first, then clean up the resource. Stale ownerReferences are harmless by themselves — a phantom recreator is the real problem."*

> **Inspector Ahmed's Rule #83:** Resource keeps reappearing after deletion? Something is recreating it. Search for controllers or operators that manage that resource type. Stop the controller, then delete. Check ownerReferences to understand the ownership chain.
