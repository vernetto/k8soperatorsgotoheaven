# Episode 21 — "The Missing Brain"
### *Inspector Ahmed and the cluster with no scheduler*

**Culprit:** kube-scheduler pod crashed — all new pods stuck in Pending
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `scheduler` `control-plane` `kube-system` `pending`

---

## OPENING — Crime scene

"Every new pod in every namespace was Pending. Not some pods — all pods. Every deployment, every job, every system pod. The cluster had lost its ability to think."

```bash
kubectl get pods --all-namespaces | grep Pending | wc -l
```

```
47
```

47 pods pending across the cluster. This isn't a resource problem. When it's everything, it's infrastructure.

---

## ACT I — The brain check

```bash
kubectl get pods -n kube-system
```

```
NAME                                    READY   STATUS             RESTARTS   AGE
etcd-control-plane                      1/1     Running            0          45d
kube-apiserver-control-plane            1/1     Running            0          45d
kube-controller-manager-control-plane   1/1     Running            0          45d
kube-scheduler-control-plane            0/1     CrashLoopBackOff   14         1h
coredns-5d78c9869d-4xk2p                1/1     Running            0          45d
```

`kube-scheduler` is crashing. This is why nothing is being scheduled.

```bash
kubectl logs kube-scheduler-control-plane -n kube-system --previous
```

```
E0314 09:22:14.000000       1 scheduler.go:598]
  Error getting node "node-1" from cache: node not found
panic: runtime error: invalid memory address or nil pointer dereference
goroutine 1 [running]:
k8s.io/kubernetes/pkg/scheduler/...
```

A panic in the scheduler. A recent upgrade introduced a bug that crashes the scheduler when a node is temporarily unavailable.

> **📚 Teaching moment — Static pods and control plane**
>
> On kubeadm-provisioned clusters, control plane components (scheduler, controller-manager, API server, etcd) run as **static pods** — defined by YAML files in `/etc/kubernetes/manifests/` on the control plane node. The kubelet watches this directory and keeps these pods running. They don't go through the normal scheduler — the kubelet starts them directly.
>
> This is why even with a broken scheduler, you can still run `kubectl` — the API server is still up.

---

## ACT II — Restoring the scheduler

Ahmed SSH's to the control plane node:

```bash
ssh control-plane-node
cat /etc/kubernetes/manifests/kube-scheduler.yaml | grep image
```

```
image: registry.k8s.io/kube-scheduler:v1.28.5
```

The cluster was recently upgraded to v1.28.5 which has a known bug. Ahmed rolls back the scheduler image:

```bash
sed -i 's/v1.28.5/v1.28.4/' /etc/kubernetes/manifests/kube-scheduler.yaml
```

The kubelet detects the change and restarts the scheduler pod within seconds.

```bash
kubectl get pods -n kube-system | grep scheduler
```

```
kube-scheduler-control-plane   1/1   Running   0   15s
```

```bash
kubectl get pods --all-namespaces | grep Pending | wc -l
```

```
0
```

All 47 pending pods are scheduled within 30 seconds.

---

## EPILOGUE

*"When all pods across all namespaces are Pending simultaneously, don't look at the pods — look at kube-system. The scheduler, controller-manager, or API server is the culprit. Always check the control plane first."*

> **Inspector Ahmed's Rule #21:** All pods Pending everywhere = control plane problem. Check kube-system. Check kube-scheduler logs. The API might be up but the brain is gone.
