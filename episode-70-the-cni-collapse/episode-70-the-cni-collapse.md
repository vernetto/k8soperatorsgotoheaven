# Episode 70 — "The CNI Collapse"
### *Inspector Ahmed and the networking plugin that takes the whole cluster down with it*

**Culprit:** Calico/Cilium node agent crash — pod networking broken on one node
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `cni` `calico` `cilium` `networking` `daemonset`

---

## OPENING — Crime scene

"All pods on node-2 suddenly lost network connectivity. They were Running — but couldn't reach anything. New pods scheduled to node-2 started but had no network interface. The CNI plugin had crashed."

```bash
kubectl get pods -n production -o wide | grep node-2
```

```
NAME                  READY   STATUS    NODE     AGE
api-7f9d4b-xk2p       1/1     Running   node-2   2h   ← no network
api-7f9d4b-r8tn       0/1     Pending   <none>   5m   ← rescheduled away
```

```bash
kubectl exec api-7f9d4b-xk2p -n production -- \
  curl http://backend-api:8080 --max-time 3
```

```
curl: (6) Could not resolve host: backend-api
```

DNS failing from node-2. Not a CoreDNS problem — the pod can't reach the DNS IP at all.

---

## ACT I — CNI agent on node-2

```bash
kubectl get pods -n kube-system -o wide | grep -E "calico|cilium" | grep node-2
```

```
calico-node-r8tn   0/1   CrashLoopBackOff   12   node-2
```

The Calico node agent is crashing on node-2. Without it, no network rules are set up for pods on that node.

```bash
kubectl logs calico-node-r8tn -n kube-system --previous | tail -20
```

```
2024-03-14 10:22:14.000 [ERROR] Unable to connect to etcd:
  context deadline exceeded
  peer urls: [https://192.168.1.1:2379]
2024-03-14 10:22:14.000 [FATAL] Failed to connect to datastore
```

Calico uses etcd as its datastore. The etcd connection from node-2 is timing out — likely a network partition or firewall rule added between node-2 and the control plane.

> **📚 Teaching moment — CNI plugin architecture**
>
> The CNI (Container Network Interface) plugin runs as a DaemonSet on every node. It's responsible for:
> - Assigning IP addresses to pods
> - Setting up network interfaces in pod network namespaces
> - Programming routing rules and iptables/eBPF rules for inter-pod traffic
>
> If the CNI DaemonSet pod on a node crashes, new pods on that node get no network interface. Existing pods keep their network (it's configured at pod creation) but may lose routing if eBPF/iptables rules are cleared.

---

## ACT II — Fixing the connection

```bash
# Check firewall rules from node-2 to control plane
ssh node-2 -- nc -zv 192.168.1.1 2379
```

```
nc: connect to 192.168.1.1 port 2379 (tcp) failed: Connection refused
```

A security group change blocked etcd port 2379 from worker nodes. The ops team restores the rule:

```bash
# AWS example: allow port 2379 from worker security group
aws ec2 authorize-security-group-ingress \
  --group-id sg-control-plane \
  --protocol tcp --port 2379 \
  --source-group sg-workers
```

```bash
kubectl delete pod calico-node-r8tn -n kube-system
# DaemonSet restarts it
kubectl get pod calico-node-r8tn -n kube-system
```

```
NAME               READY   STATUS    RESTARTS   AGE
calico-node-r8tn   1/1     Running   0          30s
```

Network on node-2 restored within 30 seconds.

---

## EPILOGUE

*"A node where all pods lose network simultaneously — but the node stays Ready — has a CNI problem. The CNI agent is your networking janitor. When it crashes, the network breaks. Check the CNI DaemonSet first, then look at why it's crashing."*

> **Inspector Ahmed's Rule #70:** All pods on one node losing network while node stays Ready? CNI agent crashed. `kubectl get pods -n kube-system -o wide | grep <cni-name> | grep <node>`. Read the logs. Usually it's a connectivity issue to the CNI datastore.
