# Episode 50 — "The Midnight Rollback"
### *Inspector Ahmed and the deployment history that was erased*

**Culprit:** `revisionHistoryLimit: 0` — no rollback available after a bad deploy
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `rollback` `revisionhistory` `deployment` `replicaset`

---

## OPENING — Crime scene

"The deployment was bad. The team needed to rollback. But `kubectl rollout undo` reported there was nothing to undo. The history had been wiped. Someone had been 'optimising' for disk space."

```bash
kubectl rollout undo deployment/api -n production
```

```
error: no rollout history found for deployment "api"
```

```bash
kubectl rollout history deployment/api -n production
```

```
REVISION  CHANGE-CAUSE
1         <none>
```

Only one revision. No previous version to roll back to.

---

## ACT I — The missing history

```bash
kubectl get deployment api -n production -o yaml | grep revisionHistoryLimit
```

```
  revisionHistoryLimit: 0
```

`revisionHistoryLimit: 0`. This tells Kubernetes to immediately delete old ReplicaSets after a successful deployment. Zero old versions kept. Zero rollback available.

> **📚 Teaching moment — revisionHistoryLimit**
>
> Kubernetes keeps old ReplicaSets to enable rollback. The `revisionHistoryLimit` field controls how many to keep. Default: 10.
>
> Setting it to 0 deletes old ReplicaSets immediately after deployment — saving some storage (ReplicaSet objects are tiny) at the cost of losing all rollback capability.
>
> Setting it to 0 in production is almost always a mistake. The storage savings are negligible; the operational cost is catastrophic during incidents.

---

## ACT II — Recovery without rollback

No old ReplicaSet exists. Ahmed must deploy the previous known-good image manually:

```bash
# Check the git log for the previous image tag
git log --oneline -5 -- k8s/production/api-deployment.yaml
```

```
a3f8c12  deploy: bump to v3.2.1
d91e045  deploy: bump to v3.1.9
```

```bash
kubectl set image deployment/api \
  api=registry.company.com/api:v3.1.9 \
  -n production
```

The service recovers. The post-incident fix:

```yaml
spec:
  revisionHistoryLimit: 5   # keep last 5 revisions
```

---

## EPILOGUE

*"revisionHistoryLimit: 0 is not an optimisation. It's removing your emergency brake. Keep at least 3 revisions in production. The few kilobytes of ReplicaSet metadata are worth infinitely more than the rollback capability they enable."*

> **Inspector Ahmed's Rule #50:** Can't rollback? Check `revisionHistoryLimit`. If it's 0, you have no history. Set it to at least 3. Roll back by manually setting the previous image tag from git.
