# Episode 33 — "The Jealous Node"
### *Inspector Ahmed and the pod that only schedules on one node*

**Culprit:** Pod anti-affinity prevents spreading — all replicas land on same node
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `anti-affinity` `affinity` `pod-distribution` `high-availability`

---

## OPENING — Crime scene

"High availability deployment: 3 replicas. All 3 replicas on the same node. When that node went down for maintenance, all 3 pods were evicted simultaneously. Zero redundancy achieved."

```bash
kubectl get pods -n production -o wide
```

```
NAME                  READY   STATUS    NODE       AGE
api-7f9d4b-xk2p       1/1     Running   node-1     2h
api-7f9d4b-r8tn       1/1     Running   node-1     2h
api-7f9d4b-9lmw       1/1     Running   node-1     2h
```

All three replicas on `node-1`. The deployment has no affinity rules — the scheduler placed them all on the node with the most available resources.

> **📚 Teaching moment — Pod Anti-Affinity**
>
> Pod anti-affinity tells the scheduler: *don't schedule this pod on a node that already has pods matching this selector.*
>
> Two types:
> - **requiredDuringSchedulingIgnoredDuringExecution**: hard rule — pod stays Pending if it can't be placed on a different node
> - **preferredDuringSchedulingIgnoredDuringExecution**: soft rule — scheduler tries to spread but will co-locate if it has to

---

## ACT II — Adding anti-affinity

```yaml
spec:
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values:
              - api
          topologyKey: kubernetes.io/hostname
```

`topologyKey: kubernetes.io/hostname` means "different host". After applying:

```bash
kubectl rollout restart deployment/api -n production
kubectl get pods -n production -o wide
```

```
NAME                  READY   STATUS    NODE       AGE
api-8e2a1c-xk2p       1/1     Running   node-1     30s
api-8e2a1c-r8tn       1/1     Running   node-2     28s
api-8e2a1c-9lmw       1/1     Running   node-3     26s
```

One pod per node. True high availability.

---

## EPILOGUE

*"Three replicas on one node isn't HA — it's three times the blast radius. Add pod anti-affinity to every deployment that calls itself highly available. It's a 10-line YAML addition that makes the '3 replicas' actually mean something."*

> **Inspector Ahmed's Rule #33:** Always add `podAntiAffinity` with `topologyKey: kubernetes.io/hostname` to any deployment with 2+ replicas that serves production traffic. Otherwise, all replicas might land on one node.
