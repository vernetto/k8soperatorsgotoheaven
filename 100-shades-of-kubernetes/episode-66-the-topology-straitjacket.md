# Episode 66 — "The Topology Straitjacket"
### *Inspector Ahmed and the pod that can't be scheduled because of its own spreading rules*

**Culprit:** TopologySpreadConstraints too strict — not enough nodes in each zone to satisfy spread
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `topology-spread` `scheduling` `zones` `availability` `pending`

---

## OPENING — Crime scene

"The deployment had 6 replicas. Four were running. Two were Pending. The cluster had plenty of capacity. But the pods wanted to spread themselves so evenly that they couldn't fit anywhere."

```bash
kubectl describe pod api-7f9d4b-pending1 -n production
```

```
Events:
  Warning  FailedScheduling  5m  default-scheduler
    0/6 nodes are available:
    3 node(s) didn't match pod topology spread constraints.
    3 node(s) had untolerated taint.
```

Topology spread constraints are blocking scheduling.

---

## ACT I — The spread rules

```bash
kubectl get deployment api -n production -o yaml | grep -A 15 "topologySpreadConstraints"
```

```yaml
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: topology.kubernetes.io/zone
  whenUnsatisfiable: DoNotSchedule
  labelSelector:
    matchLabels:
      app: api
```

`maxSkew: 1` means: the difference between the zone with the most pods and the zone with the fewest must be ≤ 1.

```bash
kubectl get nodes --show-labels | grep zone
```

```
node-1   zone=eu-west-1a
node-2   zone=eu-west-1a
node-3   zone=eu-west-1b
```

Only two zones. 6 replicas, 2 zones. Current distribution: 4 in zone-a (nodes 1 and 2), 0 in zone-b (node 3). Skew = 4. To satisfy maxSkew=1 with 6 pods: zones must have 3 and 3. But zone-b has only 1 node — and that node has a taint the pods don't tolerate.

Result: the scheduler can't place 3 pods in zone-b (only 1 tainted node there). The constraint is unsatisfiable.

> **📚 Teaching moment — TopologySpreadConstraints**
>
> TopologySpreadConstraints are powerful for spreading pods across zones, nodes, or regions. But `whenUnsatisfiable: DoNotSchedule` means: if the constraint can't be satisfied, the pod stays Pending forever.
>
> For availability: `DoNotSchedule` is safer (ensures true spreading).
> For availability under resource pressure: `ScheduleAnyway` is more forgiving (scheduler does best effort spreading but won't block scheduling).

---

## ACT II — Two fixes

**Option A — Change to ScheduleAnyway:**

```yaml
whenUnsatisfiable: ScheduleAnyway
```

The scheduler will still try to spread, but won't block if it can't achieve perfect balance.

**Option B — Add a third zone:**

The ops team adds nodes in a third zone. The 6 replicas can now spread 2-2-2 across three zones.

The team implements Option A immediately and plans Option B for the next infrastructure cycle.

---

## EPILOGUE

*"TopologySpreadConstraints with DoNotSchedule are unforgiving. If you don't have enough zones or nodes to satisfy the spread, pods stay Pending. Either change to ScheduleAnyway or add infrastructure. Spreading is good — but not if it blocks your deployment."*

> **Inspector Ahmed's Rule #66:** Pods Pending due to topology spread constraints? Either add nodes/zones to satisfy the constraint, or change `whenUnsatisfiable: ScheduleAnyway` for flexible spreading.
