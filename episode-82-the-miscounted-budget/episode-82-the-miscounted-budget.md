# Episode 82 — "The Miscounted Budget"
### *Inspector Ahmed and the rollout that refuses to proceed past halfway*

**Culprit:** PodDisruptionBudget misconfigured for a deployment that was scaled down — blocks rolling update
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `pdb` `poddisruptionbudget` `rollout` `replicas` `deployment`

---

## OPENING — Crime scene

"A deployment had been scaled down from 10 to 3 replicas during a cost-saving exercise. Everything was fine — until someone tried to do a rolling update. The rollout started, replaced 1 pod, then froze at 2/3. The PDB and the replica count were in conflict."

```bash
kubectl rollout status deployment/api -n production
```

```
Waiting for deployment "api" rollout to finish:
  1 out of 3 new replicas have been updated...
```

Stuck at 1/3 for 20 minutes.

```bash
kubectl describe deployment api -n production | grep -A 3 "Strategy"
```

```
RollingUpdate:
  Max Unavailable: 1
  Max Surge: 0
```

maxUnavailable: 1. With 3 replicas, the update should replace one pod at a time. It replaced 1, then stopped.

---

## ACT I — The PDB math

```bash
kubectl get pdb api-pdb -n production
```

```
NAME      MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
api-pdb   3               N/A               0                     90d
```

`minAvailable: 3`. With 3 running replicas, zero pods can be disrupted — exactly what ALLOWED DISRUPTIONS: 0 means.

The PDB was written when the deployment had 10 replicas — `minAvailable: 3` meant "keep at least 3 alive during disruptions." After scaling down to 3 replicas, `minAvailable: 3` means "keep all 3 alive" — which makes rolling updates impossible.

> **📚 Teaching moment — PDB and rolling updates**
>
> Rolling updates use the same voluntary disruption mechanism as `kubectl drain`. If the PDB blocks voluntary disruptions, the rolling update stalls.
>
> When scaling a deployment down, always review PDB `minAvailable` values. A value that made sense at 10 replicas becomes a deadlock at 3.
>
> Best practice: use `maxUnavailable` instead of `minAvailable` for PDBs — it scales naturally:
> ```yaml
> maxUnavailable: 1   # always allow 1 pod to be unavailable, regardless of replica count
> ```

---

## ACT II — Fixing the PDB

```bash
kubectl patch pdb api-pdb -n production \
  --type=merge \
  -p '{"spec":{"minAvailable": null, "maxUnavailable": 1}}'
```

```bash
kubectl rollout status deployment/api -n production
```

```
Waiting for deployment "api" rollout to finish: 1 out of 3 new replicas...
Waiting for deployment "api" rollout to finish: 2 out of 3 new replicas...
deployment "api" successfully rolled out
```

---

## EPILOGUE

*"PDB minAvailable is a fixed number. When you scale the deployment down, check if minAvailable still makes sense. Use maxUnavailable instead — it's proportional and doesn't create hidden deadlocks when replica counts change."*

> **Inspector Ahmed's Rule #82:** Rolling update stalls at a specific replica count? Check the PDB. If `minAvailable == replicas`, ALLOWED DISRUPTIONS is 0 — nothing can be updated. Switch to `maxUnavailable: 1` for a PDB that scales with the deployment.
