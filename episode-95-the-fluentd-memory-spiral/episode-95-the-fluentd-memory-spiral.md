# Episode 95 — "The Fluentd Memory Spiral"
### *Inspector Ahmed and the log aggregator that ate the node*

**Culprit:** Fluentd DaemonSet with no memory limit consuming all node memory — triggers evictions
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `fluentd` `logging` `daemonset` `memory` `limits` `eviction`

---

## OPENING — Crime scene

"Pods were being evicted from multiple nodes simultaneously. Not one node — all of them. Memory pressure across the cluster. The common denominator on every node: a Fluentd DaemonSet that had been running for months, quietly accumulating memory."

```bash
kubectl top pods -n logging --sort-by=memory
```

```
NAME                  CPU(cores)   MEMORY(bytes)
fluentd-node-1        245m         4100Mi
fluentd-node-2        239m         3950Mi
fluentd-node-3        251m         4200Mi
```

4 GiB each. On nodes with 8 GiB total, Fluentd alone is consuming 50% — leaving little room for application pods.

```bash
kubectl get daemonset fluentd -n logging -o yaml | grep -A 5 "resources:"
```

```yaml
resources: {}
```

No resource limits. Fluentd is allowed to grow indefinitely.

---

## ACT I — The memory growth pattern

The Fluentd memory was growing steadily because:
1. Elasticsearch (the destination) had been slow for the past week
2. Fluentd was buffering unshipped logs in memory
3. No buffer memory limit was configured
4. Buffers filled up over days, consuming all available memory

> **📚 Teaching moment — Logging agent memory management**
>
> Log shipping agents buffer logs when the destination is slow or unavailable. Without memory limits on both the pod and the buffer configuration, the agent will consume all available memory.
>
> Fluentd buffer configuration:
> ```xml
> <buffer>
>   @type memory
>   chunk_limit_size 8MB
>   total_limit_size 256MB   # hard cap on buffer memory
>   overflow_action drop_oldest_chunk  # drop old logs rather than OOMing
> </buffer>
> ```
>
> Also always set pod-level memory limits on logging DaemonSets — they should never be BestEffort.

---

## ACT II — Adding limits

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "200Mi"
  limits:
    cpu: "500m"
    memory: "500Mi"
```

And configure Fluentd's buffer:

```xml
<buffer>
  @type memory
  total_limit_size 256MB
  overflow_action drop_oldest_chunk
</buffer>
```

After applying:

```bash
kubectl rollout restart daemonset/fluentd -n logging
kubectl top pods -n logging
```

```
NAME                  CPU(cores)   MEMORY(bytes)
fluentd-node-1        102m         198Mi
```

Memory drops to 198Mi. Evictions stop.

---

## EPILOGUE

*"DaemonSets that run on every node are especially dangerous when they have no memory limits — one misconfiguration causes cluster-wide memory pressure. Always set memory limits on logging and monitoring DaemonSets. They're infrastructure, not optional."*

> **Inspector Ahmed's Rule #95:** Cluster-wide evictions with all nodes showing memory pressure? Check DaemonSet memory limits — especially logging agents. `kubectl top pods -n logging`. Add limits and buffer caps.
