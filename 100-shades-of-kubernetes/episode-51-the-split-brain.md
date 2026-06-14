# Episode 51 — "The Split Brain"
### *Inspector Ahmed and the etcd cluster that lost quorum*

**Culprit:** etcd loses quorum after node failure — API server read-only
**Difficulty:** ⭐⭐⭐⭐ Expert
**Tags:** `etcd` `quorum` `raft` `control-plane` `disaster-recovery`

---

## OPENING — Crime scene

"The cluster was alive — barely. `kubectl get pods` worked (from cache). `kubectl apply` failed. `kubectl delete` failed. The cluster could read but not write. It had lost its voice."

```bash
kubectl get pods -n production
```

```
NAME                   READY   STATUS    RESTARTS   AGE
api-7f9d4b-xk2p        1/1     Running   0          2h
```

Reads work. But:

```bash
kubectl scale deployment api --replicas=5 -n production
```

```
Error from server (ServiceUnavailable): etcdserver: request timed out
```

Writes fail. etcd is in a degraded state.

---

## ACT I — Checking etcd health

```bash
kubectl get pods -n kube-system | grep etcd
```

```
etcd-control-plane-1   1/1   Running   0   45d
etcd-control-plane-2   0/1   Error     4   1h
etcd-control-plane-3   1/1   Running   0   45d
```

Three-node etcd cluster. One node in Error. With 3 nodes, quorum requires 2. 2 nodes are running — quorum should be maintained. Ahmed digs deeper:

```bash
kubectl exec etcd-control-plane-1 -n kube-system -- \
  etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key
```

```
8e9e05c52164694d, started, control-plane-1, https://192.168.1.1:2380, https://192.168.1.1:2379
91bc3c398fb3c146, started, control-plane-2, https://192.168.1.2:2380, https://192.168.1.2:2379
fd422379fda50e48, unstarted, control-plane-3, https://192.168.1.3:2380, https://192.168.1.3:2379
```

`control-plane-3` shows as `unstarted` — it joined the cluster spec but never fully bootstrapped. Its vote counts in the quorum calculation but it never participates. Effective quorum: 2 required, but only 1.5 functional. Writes fail intermittently.

> **📚 Teaching moment — etcd Raft quorum**
>
> etcd uses the Raft consensus protocol. For a cluster of N nodes, quorum = ⌊N/2⌋ + 1.
> - 3 nodes: quorum = 2. Can tolerate 1 failure.
> - 5 nodes: quorum = 3. Can tolerate 2 failures.
>
> If quorum is lost, etcd rejects writes to prevent split-brain scenarios. The cluster becomes read-only from the API server's perspective.

---

## ACT II — Recovery

Ahmed removes the non-functional member and re-adds it cleanly:

```bash
# Remove the unstarted member
kubectl exec etcd-control-plane-1 -n kube-system -- \
  etcdctl member remove fd422379fda50e48 \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key
```

With the unstarted member removed, the 2-node cluster (control-plane-1 and control-plane-2) has quorum again. Writes resume.

Control-plane-3 is then rebuilt and re-joined following the kubeadm join procedure.

---

## EPILOGUE

*"etcd quorum loss makes the cluster read-only. It's not a crash — it's a safety mechanism. To recover: understand which members are functional, remove non-functional ones to restore quorum, then rebuild. Always run 3 or 5 etcd members, never 2 or 4."*

> **Inspector Ahmed's Rule #51:** Reads work but writes fail with `etcdserver: request timed out`? etcd lost quorum. Use `etcdctl member list` to find unstarted or unreachable members. Remove them to restore quorum. Never run an even number of etcd nodes.
