# Episode 91 — "The Node Pressure Cascade"
### *Inspector Ahmed and the node that starts evicting everything under pressure*

**Culprit:** Memory pressure on one node causes a cascade of evictions across the cluster
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `memory-pressure` `eviction` `qos` `burstable` `guaranteed`

---

## OPENING — Crime scene

"Pods were being evicted from node-1 seemingly at random. High-priority pods. Low-priority pods. All kinds. The node wasn't OOMKilled — it was under memory pressure and the kubelet was choosing victims."

```bash
kubectl describe node node-1 | grep MemoryPressure
```

```
MemoryPressure   True   KubeletHasInsufficientMemory
```

`MemoryPressure: True`. The kubelet's eviction manager has detected that available memory is below the eviction threshold.

---

## ACT I — The QoS classes

```bash
kubectl get pods -n production -o custom-columns=\
"NAME:.metadata.name,QOS:.status.qosClass" | sort -k2
```

```
NAME                     QOS
batch-worker-7f9d-xk2p   BestEffort
api-7f9d4b-xk2p          Burstable
api-7f9d4b-r8tn          Burstable
database-0               Guaranteed
cache-6d8f9c-mn2x        BestEffort
```

> **📚 Teaching moment — Kubernetes QoS classes**
>
> Kubernetes assigns pods a QoS (Quality of Service) class based on their resource specs:
>
> - **Guaranteed**: requests == limits for ALL containers (CPU and memory). These pods are the LAST to be evicted under memory pressure.
> - **Burstable**: requests < limits, or only some containers have resources set. Evicted after BestEffort pods.
> - **BestEffort**: no resource requests or limits set at all. These are the FIRST to be evicted under memory pressure.
>
> During memory pressure, the kubelet evicts pods in this order: BestEffort first, then Burstable (starting with those exceeding their requests), then Guaranteed.

---

## ACT II — The root cause

Ahmed identifies the memory hog:

```bash
kubectl top pods -n production --sort-by=memory | head -5
```

```
NAME                     CPU(cores)   MEMORY(bytes)
batch-worker-7f9d-xk2p   45m          4890Mi
```

The batch worker has no memory limit (BestEffort) and consumed 4.9 GiB — pushing the node into memory pressure. It gets evicted first — but not before it triggered evictions of Burstable pods too.

Fix 1: add resource limits to the batch worker:

```yaml
resources:
  requests:
    memory: "256Mi"
  limits:
    memory: "512Mi"
```

Fix 2: ensure critical services are `Guaranteed` QoS:

```yaml
# Make the api pods Guaranteed by setting requests == limits
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

---

## EPILOGUE

*"BestEffort pods are the first evicted under memory pressure. A single unmetered BestEffort pod can consume all node memory and trigger a cascade of evictions. Always set resource limits. Make critical services Guaranteed by setting requests == limits."*

> **Inspector Ahmed's Rule #91:** Random evictions under memory pressure? Check QoS classes. BestEffort pods with no limits can eat all memory. Set limits on everything. Make critical pods Guaranteed (requests == limits).
