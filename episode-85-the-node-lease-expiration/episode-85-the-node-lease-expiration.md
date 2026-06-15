# Episode 85 — "The Node Lease Expiration"
### *Inspector Ahmed and the node that is declared dead while alive*

**Culprit:** Node heartbeat delayed — controller-manager declares node NotReady, evicts pods from a live node
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `node-lease` `heartbeat` `controller-manager` `notready` `eviction`

---

## OPENING — Crime scene

"Pods were being evicted from node-3 and rescheduled. But node-3 was perfectly healthy — the applications on it were serving traffic. The problem was that the control plane had decided node-3 was dead, even though it wasn't."

```bash
kubectl describe node node-3 | grep -A 5 "Conditions:"
```

```
Conditions:
  Type    Status    LastHeartbeatTime             Reason
  ----    ------    -----------------             ------
  Ready   Unknown   2024-03-14T10:20:00Z          NodeStatusUnknown
```

`NodeStatusUnknown` — the controller-manager hasn't received a heartbeat from this node for long enough that it declared it unknown. After a further timeout, it would be `NotReady` and pods would be evicted.

```bash
# On node-3 directly — the node is responsive
uptime
```

```
10:35:22 up 45 days, 2:14, 1 user, load average: 0.42, 0.38, 0.35
```

The node is alive. But its heartbeat isn't reaching the control plane.

---

## ACT I — Node lease mechanism

```bash
kubectl get lease -n kube-node-lease | grep node-3
```

```
NAME      HOLDER    AGE    RENEW-TIME
node-3    node-3    45d    2024-03-14T10:20:00Z   ← 15 minutes ago
```

The lease was last renewed 15 minutes ago. The kubelet on node-3 renews this lease every 10 seconds by default. 15 minutes of no renewal = something is blocking the kubelet's API server communication.

```bash
# On node-3
journalctl -u kubelet | grep -i "error\|timeout" | tail -20
```

```
Mar 14 10:20:01 kubelet[1234]: Failed to update node lease:
  Post "https://192.168.1.1:6443/apis/coordination.k8s.io/v1/...":
  dial tcp 192.168.1.1:6443: i/o timeout
```

The kubelet can't reach the API server. A network issue (a firewall rule change, a routing problem) severed the connection between node-3 and the control plane.

> **📚 Teaching moment — Node heartbeat and lease**
>
> The kubelet reports node health through two mechanisms:
> 1. **NodeStatus updates**: full node status updates, every `nodeStatusUpdateFrequency` (default: 10s)
> 2. **Node Lease**: a lightweight heartbeat using a `Lease` object in `kube-node-lease` namespace, renewed every `nodeLeaseRenewIntervalFraction` (default: 10s)
>
> The controller-manager marks a node `NotReady` after `node-monitor-grace-period` (default: 40s) without a heartbeat. After `pod-eviction-timeout` (default: 5 minutes of NotReady), pods are evicted.
>
> If the node is actually alive but network-partitioned from the control plane, pods get evicted from a healthy node.

---

## ACT II — Restoring connectivity

The firewall team identifies a new security rule that was blocking port 6443 from node-3's IP range:

```bash
# Restore API server access from node-3
# (cloud provider firewall example)
aws ec2 authorize-security-group-ingress \
  --group-id sg-api-server \
  --protocol tcp --port 6443 \
  --source-group sg-workers
```

Within 30 seconds, the kubelet reconnects, the node lease is renewed, and the node transitions back to `Ready`.

---

## EPILOGUE

*"NodeStatusUnknown means the control plane lost contact with the node — not that the node is broken. Check network connectivity between the node and the API server port (6443). Firewall changes are the most common cause."*

> **Inspector Ahmed's Rule #85:** Node shows NotReady or Unknown while apps on it are serving traffic? The node is alive but network-partitioned from the control plane. Check port 6443 access from the node. Check node lease renewal time.
