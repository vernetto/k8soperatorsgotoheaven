# Episode 62 — "The LimitRange Trap"
### *Inspector Ahmed and the pod that can't be created because of invisible defaults*

**Culprit:** LimitRange sets default limits — pod's explicit request exceeds LimitRange maximum
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `limitrange` `resources` `namespace` `requests` `limits`

---

## OPENING — Crime scene

"The pod spec looked correct. The resources were reasonable. But kubectl refused to create it, citing limit violations — limits that weren't even in the pod spec."

```bash
kubectl apply -f high-memory-job.yaml
```

```
Error from server (Forbidden): error when creating "high-memory-job.yaml":
  pods "data-crunch" is forbidden:
  [maximum memory usage per Container is 4Gi,
   but limit is 8Gi.]
```

The pod requests 8Gi memory. Something is limiting containers to 4Gi.

---

## ACT I — The LimitRange

```bash
kubectl get limitrange -n batch
```

```
NAME              CREATED AT
batch-limits      2024-01-15T10:00:00Z
```

```bash
kubectl describe limitrange batch-limits -n batch
```

```
Type        Resource   Min    Max    Default Request   Default Limit   Max Limit/Request Ratio
----        --------   ---    ---    ---------------   -------------   -----------------------
Container   cpu        100m   4000m  250m              1000m           -
Container   memory     64Mi   4Gi    256Mi             1Gi             -
```

Maximum memory per container: **4Gi**. The job requests 8Gi. Forbidden.

> **📚 Teaching moment — LimitRange**
>
> A LimitRange operates at the namespace level and enforces:
> - **Min**: minimum resource request/limit for containers
> - **Max**: maximum resource request/limit for containers
> - **Default**: applied to containers that don't specify requests/limits
> - **DefaultRequest**: default request if not specified
>
> Unlike ResourceQuota (which limits namespace totals), LimitRange limits *per-container* values.
>
> LimitRange also provides defaults — if you create a pod without resource specs, it gets the LimitRange defaults. This prevents unlimited containers in controlled namespaces.

---

## ACT II — Options

**Option A — Reduce the job's memory request** (if 8Gi was excessive):

```yaml
resources:
  requests:
    memory: "3Gi"
  limits:
    memory: "4Gi"
```

**Option B — Update the LimitRange** (if 4Gi is genuinely insufficient for batch jobs):

```bash
kubectl patch limitrange batch-limits -n batch \
  --type=merge \
  -p '{"spec":{"limits":[{"type":"Container","max":{"memory":"16Gi","cpu":"8000m"}}]}}'
```

**Option C — Move the job to a namespace with higher limits** (if batch jobs are special-cased).

---

## EPILOGUE

*"LimitRange silently applies defaults and enforces ceilings. When a pod is rejected with 'maximum ... exceeded', you have a LimitRange. Check it before fighting the pod spec. Either reduce your request or increase the LimitRange — don't fight invisible walls blindly."*

> **Inspector Ahmed's Rule #62:** Pod creation fails with 'maximum ... exceeded'? Check `kubectl describe limitrange -n <ns>`. Adjust either the pod request or the LimitRange max, depending on which is wrong.
