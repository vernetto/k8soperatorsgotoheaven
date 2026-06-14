# Episode 6 — "The Hoarder"
### *Inspector Ahmed and the node that ran out of room*

**Culprit:** Node disk full — kubelet evicts pods to reclaim space
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `eviction` `disk-pressure` `node` `ephemeral-storage` `logs`

---

## OPENING — Crime scene

"Three pods evicted in the span of ten minutes. No memory pressure. No CPU spike. The node looked healthy on every dashboard — except one metric nobody had bothered to add an alert on: disk usage."

```bash
kubectl get pods -n production
```

```
NAME                        READY   STATUS    RESTARTS   AGE
api-7f9d4b-xk2p9            0/1     Evicted   0          8m
api-7f9d4b-r8tn1            0/1     Evicted   0          6m
api-7f9d4b-9lmw3            0/1     Evicted   0          4m
api-7f9d4b-mn2xp            1/1     Running   0          1m
```

`Evicted`. Not crashed — *evicted*. The kubelet removed these pods from the node.

---

## ACT I — Reading the eviction notice

```bash
kubectl describe pod api-7f9d4b-xk2p9 -n production
```

```
Status: Failed
Reason: Evicted
Message: The node was low on resource: ephemeral-storage.
         Threshold quantity: 10%, available: 2%.
         Container api was using 4Gi, which exceeds its request of 0.
```

The node ran out of ephemeral storage. The kubelet's eviction manager detected the disk was at 98% capacity and started removing pods to free space.

> **📚 Teaching moment — Kubelet eviction**
>
> The kubelet monitors node resources continuously. When a resource crosses a threshold, it starts evicting pods — choosing which ones to kill based on priority, whether they exceed their requests, and how much they're over.
>
> Default eviction thresholds:
> - **memory.available** < 100Mi
> - **nodefs.available** < 10% (disk where pods write logs and ephemeral data)
> - **nodefs.inodesFree** < 5%
> - **imagefs.available** < 15% (disk where container images are stored)
>
> Eviction is not a crash. It's the kubelet doing its job: protecting the node.

---

## ACT II — Finding the disk hog

```bash
kubectl describe node node-2
```

```
Conditions:
  Type                 Status   Reason
  ----                 ------   ------
  DiskPressure         True     KubeletHasDiskPressure
  MemoryPressure       False    KubeletHasNoPressure
  PIDPressure          False    KubeletHasNoPIDPressure
  Ready                True     KubeletReady
```

`DiskPressure: True`. Ahmed SSH's onto the node to investigate.

```bash
df -h
```

```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        50G   49G  500M  99% /
```

99%. He finds who is responsible:

```bash
du -sh /var/log/containers/* | sort -rh | head -20
```

```
18G  /var/log/containers/log-generator-5d9f4b_production_app-abc123.log
12G  /var/log/containers/audit-writer-7f9d4b_production_writer-def456.log
 4G  /var/log/containers/api-7f9d4b_production_api-ghi789.log
```

A pod called `log-generator` has produced **18 GB of logs**. It's a service that was supposed to write structured logs but had a misconfiguration causing it to log every single database query in verbose mode — for three weeks.

> **📚 Teaching moment — Ephemeral storage and log rotation**
>
> Container logs in Kubernetes are stored on the node at `/var/log/containers/`. By default, `kubelet` handles log rotation via `containerLogMaxSize` and `containerLogMaxFiles`, but defaults are often generous (10MB × 5 files = 50MB per container). A chatty application can blow past this.
>
> Best practices:
> - Set `containerLogMaxSize: 10Mi` and `containerLogMaxFiles: 3` in kubelet config
> - Use `ephemeral-storage` limits in pod specs to prevent a single pod from consuming all node disk
> - Ship logs to a central system (Loki, Elasticsearch) and don't rely on node-local storage

---

## ACT III — The cleanup

```bash
# Emergency: truncate the offending log file
truncate -s 0 /var/log/containers/log-generator-5d9f4b_production_app-abc123.log

# Fix the log-generator configuration to stop verbose mode
kubectl set env deployment/log-generator LOG_LEVEL=warn -n production

# Delete the evicted pod ghosts (they stay as Failed pods until manually cleaned)
kubectl delete pods --field-selector=status.phase=Failed -n production
```

---

## EPILOGUE

*"Evicted pods are victims, not criminals. The criminal is whatever filled the disk. Always follow the disk usage to the real culprit — it's almost always a log file that nobody knew was growing."*

> **📚 Episode takeaways**
>
> | Command | What it's for |
> |---|---|
> | `kubectl describe node` → Conditions | Check for DiskPressure, MemoryPressure |
> | `kubectl describe pod` → Message | Read the eviction reason |
> | `du -sh /var/log/containers/*` | Find the disk hog on the node |
> | `kubectl delete pods --field-selector=status.phase=Failed` | Clean up evicted pod records |
>
> **Inspector Ahmed's Rule #6:** Evicted pods are symptoms. SSH to the node, check disk, and find what's eating space. Bet on logs.
