# Episode 65 — "The New Node's Rejection"
### *Inspector Ahmed and the DaemonSet that misses newly joined nodes*

**Culprit:** DaemonSet not scheduling on new nodes — node has a taint the DaemonSet doesn't tolerate
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `daemonset` `taints` `tolerations` `nodes` `monitoring`

---

## OPENING — Crime scene

"A new node was added to the cluster. The monitoring DaemonSet should have automatically deployed to it. It didn't. The node had no log collector, no metrics exporter, no network plugin. It was flying blind."

```bash
kubectl get daemonset node-exporter -n monitoring
```

```
NAME            DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
node-exporter   3         3         3       3            3           <none>           90d
```

DESIRED: 3. But the cluster now has 4 nodes.

```bash
kubectl get nodes
```

```
NAME        STATUS   ROLES    AGE    VERSION
node-1      Ready    <none>   90d    v1.28.3
node-2      Ready    <none>   90d    v1.28.3
node-3      Ready    <none>   90d    v1.28.3
node-4      Ready    <none>   2h     v1.28.3   ← new node
```

```bash
kubectl describe node node-4 | grep Taint
```

```
Taints: node.kubernetes.io/not-ready:NoSchedule
```

The new node still has the `not-ready` taint applied during bootstrapping. But Ahmed also checks — 2 hours later, the node is `Ready`. Why is the taint still there?

---

## ACT I — The custom taint

```bash
kubectl describe node node-4 | grep -A 5 Taint
```

```
Taints:
  node.kubernetes.io/not-ready:NoSchedule
  dedicated=gpu-workloads:NoSchedule
```

Two taints. The `not-ready` taint clears automatically when kubelet is healthy. But `dedicated=gpu-workloads:NoSchedule` is a custom taint the ops team added — to reserve this node for GPU workloads.

The `node-exporter` DaemonSet tolerates `not-ready` (system DaemonSets do by default) but not `dedicated=gpu-workloads`. So it never schedules there.

> **📚 Teaching moment — System DaemonSet tolerations**
>
> Critical system DaemonSets (like CNI plugins and kube-proxy) automatically tolerate all taints using a wildcard toleration. Monitoring DaemonSets do not — they must explicitly tolerate any custom taints on nodes they should run on.
>
> If you add a custom taint to nodes, you must also add the corresponding toleration to every DaemonSet that should run on those nodes — including monitoring, logging, and security agents.

---

## ACT II — Adding the toleration

```yaml
spec:
  template:
    spec:
      tolerations:
      - key: node.kubernetes.io/not-ready
        operator: Exists
        effect: NoSchedule
      - key: node.kubernetes.io/unreachable
        operator: Exists
        effect: NoSchedule
      - key: dedicated
        operator: Equal
        value: gpu-workloads
        effect: NoSchedule    # ← add this
```

```bash
kubectl apply -f node-exporter-daemonset.yaml
kubectl get daemonset node-exporter -n monitoring
```

```
NAME            DESIRED   CURRENT   READY
node-exporter   4         4         4
```

---

## EPILOGUE

*"Every new taint you add to a node must be paired with a toleration in every DaemonSet that should run there. Monitoring, logging, and security agents must follow the pods everywhere. Check DaemonSet DESIRED count whenever you add nodes."*

> **Inspector Ahmed's Rule #65:** New node added but DaemonSet DESIRED count didn't increase? The node has a taint the DaemonSet doesn't tolerate. Add the toleration. Every node gets every system DaemonSet.
