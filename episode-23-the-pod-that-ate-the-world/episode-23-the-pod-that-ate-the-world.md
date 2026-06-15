# Episode 23 — "The Pod That Ate the World"
### *Inspector Ahmed and the noisy neighbour*

**Culprit:** One pod consuming all node CPU — throttling other pods
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `cpu-throttling` `resources` `limits` `noisy-neighbour` `top`

---

## OPENING — Crime scene

"Response times had been climbing all afternoon. No new deploys. No obvious errors. Just everything getting slower and slower. Ahmed checked pods — all Running. Checked services — all healthy. Then he checked resource consumption."

```bash
kubectl top pods -n production --sort-by=cpu
```

```
NAME                          CPU(cores)   MEMORY(bytes)
data-processor-7f9d4b-xk2p    3920m        512Mi
api-server-6d8f9c-r8tn        180m         256Mi
worker-5c7b8a-9lmw             145m         198Mi
frontend-4b6a79-mn2x           62m          128Mi
```

The `data-processor` pod is consuming 3920 millicores — nearly 4 full CPU cores. On a node with 4 cores, it's taking almost everything.

```bash
kubectl get pod data-processor-7f9d4b-xk2p -n production -o yaml | grep -A 5 "resources:"
```

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "256Mi"
```

No CPU limit. The pod requested 100m but has no ceiling — it can consume all available CPU on the node.

> **📚 Teaching moment — CPU requests vs limits and throttling**
>
> Without a CPU limit, a pod can consume all CPU on the node during bursts. This is fine for the pod — but it starves neighbours.
>
> With a CPU limit, the kernel's CFS (Completely Fair Scheduler) throttles the container when it tries to exceed its limit. You can observe this with:
> ```bash
> kubectl exec <pod> -- cat /sys/fs/cgroup/cpu/cpu.stat
> # throttled_time shows how many nanoseconds the container was throttled
> ```
>
> Setting CPU limits too low causes throttling even at low load. Setting them too high (or not at all) causes noisy neighbour problems. The right value: measure, then set limits at 2-3x the observed average.

---

## ACT II — Setting the limit

```bash
kubectl set resources deployment data-processor \
  --limits=cpu=2000m \
  --requests=cpu=500m \
  -n production
```

CPU immediately redistributes to other pods on the node. Response times drop.

---

## EPILOGUE

*"No CPU limit means 'take as much as you want.' One hungry pod can starve an entire node. Always set CPU limits. Measure first, then set — don't guess."*

> **Inspector Ahmed's Rule #23:** Unexplained latency with no errors? Run `kubectl top pods --sort-by=cpu`. Find the noisy neighbour. Check if it has a CPU limit. Set one.
