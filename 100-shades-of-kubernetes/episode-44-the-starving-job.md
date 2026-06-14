# Episode 44 — "The Starving Job"
### *Inspector Ahmed and the batch job that never gets scheduled*

**Culprit:** Job's pod template requests more CPU than any node has allocatable
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `jobs` `resources` `requests` `scheduling` `batch`

---

## OPENING — Crime scene

"A batch processing job was submitted. It sat in `Pending` indefinitely. No resource pressure on the cluster — most nodes were idle. The job was asking for something no single node could ever provide."

```bash
kubectl get jobs -n batch
```

```
NAME                COMPLETIONS   DURATION   AGE
data-transform      0/1           -          2h
```

```bash
kubectl describe job data-transform -n batch
```

```
Events:
  Warning  FailedCreate  2h  job-controller
    Error creating: pods "data-transform-" is forbidden:
    [maximum cpu usage per Pod is 4, but limit is 32.]
```

Wait — there's a LimitRange. And there's also a scheduling issue. Ahmed looks at the pod template:

```bash
kubectl get job data-transform -n batch -o yaml | grep -A 8 "resources:"
```

```yaml
resources:
  requests:
    cpu: "16"
    memory: "64Gi"
```

16 CPU cores and 64 GiB memory. Ahmed checks the largest node:

```bash
kubectl describe nodes | grep -A 5 "Allocatable"
```

```
Allocatable:
  cpu:     8
  memory:  30Gi
```

8 cores. 30 GiB. The job requests twice the capacity of the largest node. It can never be scheduled — not because the cluster is busy, but because no single node can satisfy the request.

---

## ACT II — The investigation

The job was written for an on-premises cluster with 32-core nodes. It was submitted unchanged to a cloud cluster with smaller nodes.

Options:
1. **Split the job** into smaller parallel jobs using a Job's `parallelism` and `completions` fields
2. **Add a larger node** to the cluster (if the workload genuinely requires it)
3. **Reduce resource requests** if the original estimates were wrong

```yaml
spec:
  parallelism: 4          # run 4 pods concurrently
  completions: 16         # 16 total executions needed
  template:
    spec:
      containers:
      - name: processor
        resources:
          requests:
            cpu: "3"
            memory: "14Gi"
```

Each pod now fits on a node. 4 run in parallel. Total work is distributed.

---

## EPILOGUE

*"A job that can never be scheduled isn't a queue — it's a permanent Pending. Always check that your job's resource requests fit within the capacity of your actual nodes. kubectl describe nodes tells you the maximum."*

> **Inspector Ahmed's Rule #44:** Job stuck in Pending with no resource pressure? Check if the resource requests exceed single-node capacity. `kubectl describe nodes | grep Allocatable`. If so, split the job or get bigger nodes.
