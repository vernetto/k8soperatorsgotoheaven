# Episode 52 — "The Frozen Drain"
### *Inspector Ahmed and the node that won't drain*

**Culprit:** PodDisruptionBudget blocks node drain — cluster can't do maintenance
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `pdb` `poddisruptionbudget` `drain` `maintenance` `availability`

---

## OPENING — Crime scene

"The ops team needed to drain a node for a kernel upgrade. The command had been running for forty minutes. Some pods refused to leave. The node was stuck — occupied by tenants that couldn't be asked to move."

```bash
kubectl drain node-2 --ignore-daemonsets --delete-emptydir-data
```

```
evicting pod production/api-7f9d4b-xk2p
evicting pod production/api-7f9d4b-r8tn
error when evicting pods/"api-7f9d4b-xk2p" -n "production"
  (will retry after 5s):
  Cannot evict pod as it would violate the pod's
  disruption budget: PodDisruptionBudget "api-pdb"
  with minAvailable of "3" is violated.
```

A PodDisruptionBudget is blocking the eviction.

---

## ACT I — Understanding the PDB

```bash
kubectl get pdb -n production
```

```
NAME      MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
api-pdb   3               N/A               0                     30d
```

`ALLOWED DISRUPTIONS: 0`. Zero pods can be disrupted right now.

```bash
kubectl get pods -n production | grep api
```

```
NAME               READY   STATUS    RESTARTS   AGE
api-7f9d4b-xk2p    1/1     Running   0          2h
api-7f9d4b-r8tn    1/1     Running   0          2h
api-7f9d4b-9lmw    1/1     Running   0          2h
```

Three pods. PDB requires minAvailable=3. Draining one pod would leave 2 — below the minimum. The PDB is working exactly as designed.

> **📚 Teaching moment — PodDisruptionBudget**
>
> A PDB ensures a minimum number of pods remain available during voluntary disruptions (drains, rollouts). It's the mechanism that makes "please remove this pod from this node" safe.
>
> `minAvailable: 3` with 3 running pods = zero pods can be evicted. To drain, you need at least 4 pods running, so evicting one still leaves 3.
>
> `maxUnavailable: 1` with 3 pods = 1 pod can be evicted (2 still available).
>
> PDBs only block *voluntary* disruptions (kubectl drain). Involuntary disruptions (node crash, OOM kill) are not blocked.

---

## ACT II — Two paths forward

**Option A — Scale up temporarily, then drain:**

```bash
kubectl scale deployment api --replicas=4 -n production
# Wait for the 4th pod to be Running
kubectl drain node-2 --ignore-daemonsets --delete-emptydir-data
# Now draining one pod leaves 3 — PDB satisfied
```

**Option B — Change the PDB temporarily:**

```bash
kubectl patch pdb api-pdb -n production \
  --type=merge \
  -p '{"spec":{"minAvailable":2}}'
# Drain
kubectl drain node-2 --ignore-daemonsets --delete-emptydir-data
# Restore
kubectl patch pdb api-pdb -n production \
  --type=merge \
  -p '{"spec":{"minAvailable":3}}'
```

Ahmed goes with Option A — it doesn't reduce the safety guarantee during the maintenance window.

---

## EPILOGUE

*"PDBs block drain on purpose. That's not a bug — that's the feature. To drain, you need surplus capacity above the minAvailable threshold. Scale up first, then drain. The PDB is protecting your users."*

> **Inspector Ahmed's Rule #52:** `kubectl drain` blocked by PDB? Check `kubectl get pdb`. If ALLOWED DISRUPTIONS is 0, scale up the deployment first. Never delete the PDB just to force a drain.
