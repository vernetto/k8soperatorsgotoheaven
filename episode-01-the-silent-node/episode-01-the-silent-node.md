# Episode 1 — "The Silent Node"
### *Inspector Ahmed and the pod that refuses to start*

**Culprit:** Zombie pods holding memory requests hostage
**Difficulty:** ⭐ Beginner
**Tags:** `scheduling` `resources` `memory` `pending`

---

## OPENING — Crime scene

*Voiceover, noir tone.*

"It was a Tuesday morning when the call came in. The backend team was screaming. Production pods had been `Pending` for forty minutes. No recent deploy. No declared changes. As usual."

**Inspector Ahmed** opens his laptop. First command, always the same — you don't touch anything before you look.

```bash
kubectl get pods -n production
```

```
NAME                          READY   STATUS    RESTARTS   AGE
api-deployment-7f9d4b-xk2p9   0/1     Pending   0          42m
api-deployment-7f9d4b-r8tn1   0/1     Pending   0          42m
api-deployment-7f9d4b-9lmw3   0/1     Pending   0          42m
```

Three pods. All `Pending`. All three started at the same moment — 42 minutes ago. Ahmed notes in his mental notebook: *a deployment or restart happened roughly 42 minutes ago.*

---

## ACT I — The first clue

The detective doesn't guess. The detective *reads*.

```bash
kubectl describe pod api-deployment-7f9d4b-xk2p9 -n production
```

Lines scroll past. Ahmed skips the boring sections — Environment, Volumes — and goes straight where he knows secrets hide: the **Events** section at the bottom.

```
Events:
  Type     Reason            Age   From               Message
  ----     ------            ----  ----               -------
  Warning  FailedScheduling  42m   default-scheduler  0/3 nodes are available:
                                                       3 Insufficient memory.
                                                       preemption: 0/3 nodes are
                                                       eligible for preemption:
                                                       3 No preemption victims
                                                       found for incoming pod.
```

Ahmed stops. Reads it again.

*"Insufficient memory. Three nodes. All three."*

This isn't one broken node. All three nodes in the cluster don't have enough memory to schedule the pod. The scheduler tried, found no room, and left the pods in `Pending`.

> **📚 Teaching moment — How scheduling works**
>
> In Kubernetes, the **scheduler** decides *which node* runs a pod. Before placing it, it checks two things:
> - **Requests**: how much CPU/memory the pod *declares* it needs — this is the amount *reserved* on the node
> - **Limits**: the maximum the pod is allowed to consume
>
> If no node has enough *allocatable memory* to satisfy the `request`, the pod stays `Pending`. The scheduler doesn't force it. Better to wait than to crash with an OOM kill.

---

## ACT II — Inspecting the nodes

```bash
kubectl get nodes
```

```
NAME        STATUS   ROLES    AGE   VERSION
node-1      Ready    <none>   90d   v1.28.3
node-2      Ready    <none>   90d   v1.28.3
node-3      Ready    <none>   90d   v1.28.3
```

All `Ready`. The nodes are alive. Not a health problem — a *space* problem.

```bash
kubectl describe node node-1 | grep -A 10 "Allocated resources"
```

```
Allocated resources:
  Resource           Requests      Limits
  --------           --------      ------
  cpu                1850m (92%)   3200m (160%)
  memory             3600Mi (97%)  4096Mi (110%)
```

97% of the node's memory already reserved. Almost nothing left.

```bash
kubectl describe pod api-deployment-7f9d4b-xk2p9 -n production | grep -A 5 "Requests"
```

```
    Requests:
      cpu:        500m
      memory:     1Gi
```

The pod wants 1 GiB. No node has enough free. *Case closed?* Not yet. Ahmed wants to know *why* the nodes are so packed.

---

## ACT III — Who's eating all the space?

```bash
kubectl get pods -n production -o wide
```

```
NAME                              READY   STATUS    RESTARTS   AGE
old-worker-deprecated-x7k2p       1/1     Running   0          18d
old-worker-deprecated-p9mn2       1/1     Running   0          18d
old-worker-deprecated-lkw83       1/1     Running   0          18d
data-cruncher-experimental-zxp1   1/1     Running   0          3d
```

Three "deprecated" pods — three pods that *should no longer be running* — each with 800Mi reserved. Plus an "experimental" pod holding 600Mi. Total: 3 GiB of memory held hostage by forgotten processes.

> **📚 Teaching moment — The zombie pod problem**
>
> In a shared cluster, old pods don't disappear on their own. Requests are not actual consumption: they are *reservations*. A pod can request 800Mi and use 50Mi. But the scheduler still sees 800Mi as "taken."
>
> Useful tool for finding waste:
> ```bash
> kubectl resource-capacity --sort mem.request
> # requires the kube-capacity plugin via krew
> ```

---

## ACT IV — The arrest

**Presenting problem:** Pods stuck in `Pending` with `Insufficient memory`.

**Root cause:** Zombie pods holding 3 GiB of memory requests in production, leaving no room for the new deployment.

```bash
kubectl delete deployment old-worker-deprecated -n production
kubectl delete deployment data-cruncher-experimental -n production
```

```bash
kubectl get pods -n production
```

```
NAME                          READY   STATUS    RESTARTS   AGE
api-deployment-7f9d4b-xk2p9   1/1     Running   0          3s
api-deployment-7f9d4b-r8tn1   1/1     Running   0          3s
api-deployment-7f9d4b-9lmw3   1/1     Running   0          3s
```

The pods start. The backend team stops screaming.

---

## EPILOGUE

Ahmed closes his laptop.

*"The cluster never lies. Read the Events. Look at the Requests. Criminals always leave fingerprints."*

> **📚 Episode takeaways**
>
> | Command | What it's for |
> |---|---|
> | `kubectl get pods -n <ns>` | Quick status overview |
> | `kubectl describe pod <pod>` | Read the Events — real diagnosis lives here |
> | `kubectl describe node <node>` | See allocated resources per node |
> | `kubectl get pods --all-namespaces` | Hunt for zombie pods across namespaces |
>
> **Inspector Ahmed's Rule #1:** A `Pending` pod with no image error is almost always a scheduling or resource problem. Always start with `describe pod` and go to Events.
