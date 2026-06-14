# Episode 46 — "The Hungry Etcd"
### *Inspector Ahmed and the database behind the database*

**Culprit:** etcd disk too slow — high write latency causes API server timeouts
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `etcd` `control-plane` `latency` `disk-io` `performance`

---

## OPENING — Crime scene

"API calls were timing out. `kubectl get pods` took 8 seconds. `kubectl apply` took 30 seconds — or failed. The cluster was slow, not broken. Something in the control plane was dragging."

```bash
time kubectl get pods -n production
```

```
NAME                   READY   STATUS    RESTARTS   AGE
api-7f9d4b-xk2p        1/1     Running   0          2h

real    0m8.342s
```

8 seconds to list pods. Normal is under 100ms.

---

## ACT I — Tracing to etcd

The API server stores all Kubernetes state in etcd. Every `kubectl get` query hits etcd. If etcd is slow, everything is slow.

```bash
kubectl get pod etcd-control-plane -n kube-system -o yaml | \
  grep -A 5 "command"
```

```yaml
  - etcd
  - --data-dir=/var/lib/etcd
```

etcd data is on `/var/lib/etcd`. Ahmed checks disk performance:

```bash
# SSH to control plane
fio --rw=write --ioengine=sync --fdatasync=1 \
    --directory=/var/lib/etcd --size=22m \
    --bs=2300 --name=etcd-test 2>&1 | grep "fsync/fdatasync/sync_file_range"
```

```
fsync/fdatasync/sync_file_range:
  sync percentiles (usec):
   | 99.00th=[  890],
   | 99.50th=[ 1319],
   | 99.90th=[ 5800],
   | 99.99th=[24249]
```

99th percentile fsync latency: 890 microseconds. etcd recommends < 10ms for p99. This is borderline.

```bash
iostat -x 1 5 | grep sda
```

```
Device    r/s   w/s  rMB/s wMB/s  await %util
sda       2.1   85.4   0.3   3.2   48.3  94.1
```

Disk utilisation at 94%. The control plane VM is using a spinning disk (HDD) or a very slow SSD. etcd needs fast sequential write performance.

> **📚 Teaching moment — etcd and disk performance**
>
> etcd uses the Raft consensus protocol, which requires persistent, durable writes (fsync) for every transaction. Slow disk = slow etcd = slow Kubernetes API.
>
> etcd recommendations:
> - SSD storage with **< 10ms p99 fsync latency**
> - Dedicated disk, not shared with container logs or other workloads
> - Regular defragmentation: `etcdctl defrag`
> - Regular backup

---

## ACT II — The fix

Migrate etcd data to an NVMe SSD volume:

```bash
# Stop etcd
systemctl stop etcd

# Move data to new fast volume
mv /var/lib/etcd /mnt/nvme/etcd

# Update etcd config
sed -i 's|/var/lib/etcd|/mnt/nvme/etcd|' /etc/kubernetes/manifests/etcd.yaml

# Restart
systemctl start etcd
```

```bash
time kubectl get pods -n production
```

```
real    0m0.087s
```

87 milliseconds. The cluster responds instantly.

---

## EPILOGUE

*"etcd is Kubernetes's memory. It writes every state change to disk synchronously. Give it the fastest disk you have. Never share it with application workloads. If your API is slow and everything is running, check etcd disk latency first."*

> **Inspector Ahmed's Rule #46:** Slow API server with all components running? Check etcd disk latency with fio. etcd needs NVMe or fast SSD. HDD will make your entire cluster sluggish.
