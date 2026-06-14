# Episode 14 — "The Wrong Neighborhood"
### *Inspector Ahmed and the pod that lands on the wrong node*

**Culprit:** Missing nodeAffinity — critical pod scheduled on wrong node type
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `nodeaffinity` `nodeselector` `scheduling` `affinity`

---

## OPENING — Crime scene

"The database pod was running on a spot instance. A spot instance that could be reclaimed by the cloud provider at any moment. Nobody had noticed — until the instance was reclaimed, the pod evicted, and six minutes of database downtime followed."

```bash
kubectl get pod postgres-0 -n database -o wide
```

```
NAME         READY   STATUS    NODE              AGE
postgres-0   1/1     Running   spot-node-7xk2p   2d
```

```bash
kubectl get node spot-node-7xk2p --show-labels | grep spot
```

```
node.kubernetes.io/lifecycle=spot
```

The database is running on a spot/preemptible node. These can be terminated with 2 minutes notice.

> **📚 Teaching moment — Node labels and affinity**
>
> Cloud providers label nodes by type. Common labels:
> - `node.kubernetes.io/lifecycle=spot` (spot/preemptible instance)
> - `node.kubernetes.io/lifecycle=on-demand` (regular instance)
> - `kubernetes.io/arch=amd64` or `arm64`
> - Custom labels set by your ops team: `node-type=database`, `zone=eu-west-1a`
>
> **nodeSelector**: simple key=value matching — pod only runs on nodes with that label. Rigid but easy.
> **nodeAffinity**: more expressive — required vs preferred, In/NotIn/Exists operators.

---

## ACT II — Adding nodeAffinity to the StatefulSet

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: node.kubernetes.io/lifecycle
            operator: NotIn
            values:
            - spot
```

This tells the scheduler: *never put this pod on a spot node.*

```bash
kubectl rollout restart statefulset/postgres -n database
kubectl get pod postgres-0 -n database -o wide
```

```
NAME         READY   STATUS    NODE                  AGE
postgres-0   1/1     Running   on-demand-node-r8tn   45s
```

---

## EPILOGUE

*"The scheduler places pods wherever they fit — unless you tell it otherwise. For stateful, latency-sensitive, or high-availability workloads, always define nodeAffinity. Never let chance decide where your database lives."*

> **Inspector Ahmed's Rule #14:** Stateful workloads need nodeAffinity. Check what node type your pods are running on. Spot instances can disappear in two minutes.
