# Episode 20 — "The Quota Prison"
### *Inspector Ahmed and the namespace that hit its resource ceiling*

**Culprit:** ResourceQuota exhausted — no new pods can be created
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `resourcequota` `limitrange` `namespaces` `quotas`

---

## OPENING — Crime scene

"The deployment was applied. The ReplicaSet was created. But no pods appeared. The events on the ReplicaSet told a story about limits — not of the nodes, but of the namespace itself."

```bash
kubectl get pods -n team-a
```

```
No resources found in team-a namespace.
```

```bash
kubectl describe replicaset api-7f9d4b -n team-a
```

```
Events:
  Warning  FailedCreate  2m  replicaset-controller
    Error creating: pods "api-7f9d4b-" is forbidden:
    exceeded quota: team-a-quota,
    requested: cpu=500m,memory=512Mi,
    used: cpu=9500m,memory=9.5Gi,
    limited: cpu=10000m,memory=10Gi
```

The namespace has a ResourceQuota. The team has used 9.5 CPU cores and 9.5 GiB of memory out of a 10-core/10GiB limit. The new pod would exceed both.

> **📚 Teaching moment — ResourceQuota**
>
> A ResourceQuota sets hard limits on total resource consumption within a namespace. Once reached, no new pods (or other resources) can be created until existing ones are deleted or the quota is increased.
>
> This is a multi-tenancy mechanism: it prevents one team from consuming all cluster resources.
>
> Common quota limits:
> - `requests.cpu`, `requests.memory` — total requests across all pods
> - `limits.cpu`, `limits.memory` — total limits
> - `count/pods` — maximum number of pods
> - `count/persistentvolumeclaims` — maximum PVCs

---

## ACT II — Investigating the quota

```bash
kubectl describe quota team-a-quota -n team-a
```

```
Name:            team-a-quota
Namespace:       team-a
Resource         Used    Hard
--------         ----    ----
cpu              9500m   10000m
memory           9.5Gi   10Gi
pods             19      20
```

19 pods, 9.5 cores. Ahmed checks for wasteful workloads:

```bash
kubectl top pods -n team-a --sort-by=cpu | head -10
```

He finds three pods running a completed batch job from last week, each with 2-core requests. Cleaning them up frees 6 cores.

```bash
kubectl delete job batch-report-weekly -n team-a
```

The ReplicaSet controller immediately retries and creates the pod.

---

## EPILOGUE

*"ResourceQuota is the budget. When the budget runs out, nothing new gets created. Clean up finished jobs and idle workloads first — you'll be surprised how much quota they're consuming."*

> **Inspector Ahmed's Rule #20:** `exceeded quota` on a ReplicaSet event means the namespace hit its ceiling. Check `kubectl describe quota -n <ns>` and clean up finished batch jobs or over-provisioned workloads.
