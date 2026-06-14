# Episode 13 — "The Tainted Ground"
### *Inspector Ahmed and the pod that won't land on any node*

**Culprit:** Node taint with no matching pod toleration
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `taints` `tolerations` `scheduling` `pending` `nodes`

---

## OPENING — Crime scene

"Three nodes. All healthy. Pod Pending. The scheduler wasn't finding resource issues — it was finding something else. Something written on the nodes themselves."

```bash
kubectl describe pod gpu-worker-7f9d-xk2p -n ml-jobs
```

```
Events:
  Warning  FailedScheduling  5m  default-scheduler
    0/3 nodes are available:
    3 node(s) had untolerated taint {dedicated: gpu-only}.
```

*Untolerated taint.* A new concept. Ahmed opens his notebook.

> **📚 Teaching moment — Taints and Tolerations**
>
> A **taint** is a mark on a node that repels pods. Syntax: `key=value:effect`.
> Three effects:
> - **NoSchedule**: new pods won't be scheduled here (existing pods stay)
> - **PreferNoSchedule**: scheduler avoids this node but can use it if needed
> - **NoExecute**: existing pods are evicted AND new pods won't be scheduled
>
> A **toleration** on a pod says "I can tolerate this taint — go ahead and schedule me there."
> Taints without matching tolerations = pod stays Pending.
> Common use: dedicating GPU nodes to ML workloads, keeping system pods off worker nodes.

---

## ACT I — Reading the taint

```bash
kubectl describe node gpu-node-1 | grep Taint
```

```
Taints: dedicated=gpu-only:NoSchedule
```

All three nodes have this taint. The cluster ops team added it to reserve GPU nodes for ML workloads only — so that general workloads don't land on expensive GPU machines. Good intention. But the ML job pods are missing the toleration.

---

## ACT II — Adding the toleration

```yaml
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "gpu-only"
    effect: "NoSchedule"
  containers:
  - name: gpu-worker
    image: ml-framework:latest
```

```bash
kubectl apply -f gpu-worker-deployment.yaml
kubectl get pods -n ml-jobs
```

```
NAME                        READY   STATUS    RESTARTS   AGE
gpu-worker-8a2b1c-xk2p      1/1     Running   0          15s
```

> **Note:** Tolerations allow a pod to be *scheduled* on a tainted node, but don't *force* it there. To force a pod onto specific nodes, combine tolerations with **nodeAffinity** or **nodeSelector**.

---

## EPILOGUE

*"Taints are the bouncers at the node's door. Tolerations are the VIP pass. If your pod is Pending with 'untolerated taint' in the events, the fix is one YAML block — not a cluster change."*

> **Inspector Ahmed's Rule #13:** `untolerated taint` in FailedScheduling events means the pod needs a toleration. Read the taint key/value/effect from the node, copy it into the pod spec.
