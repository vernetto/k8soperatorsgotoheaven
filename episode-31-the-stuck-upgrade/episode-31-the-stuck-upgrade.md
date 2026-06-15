# Episode 31 — "The Stuck Upgrade"
### *Inspector Ahmed and the rolling update that never finishes*

**Culprit:** Deployment strategy maxUnavailable:0 + only one replica = deadlock
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `rolling-update` `deployment-strategy` `replicas` `deadlock`

---

## OPENING — Crime scene

"The deployment was running. The rollout had been triggered. Twenty minutes later, zero progress. Old pod still running, new pod not started."

```bash
kubectl rollout status deployment/api -n production
```

```
Waiting for deployment "api" rollout to finish:
  0 out of 1 new replicas have been updated...
```

Has been saying this for 20 minutes.

```bash
kubectl get pods -n production
```

```
NAME                     READY   STATUS    RESTARTS   AGE
api-7f9d4b-xk2p           1/1     Running   0          2h
```

Only the old pod. No new pod being created.

---

## ACT I — The deadlock

```bash
kubectl describe deployment api -n production | grep -A 5 "Strategy"
```

```
Strategy:
  Type: RollingUpdate
  RollingUpdateStrategy:
    Max Unavailable: 0
    Max Surge: 0
```

`maxUnavailable: 0` means: during the update, never reduce the number of available pods below the desired count.
`maxSurge: 0` means: never create more pods than the desired count.

Desired count: 1 replica.

With both at 0: Kubernetes can't create a new pod (that would exceed 1+0=1) and can't delete the old one (that would drop below 1-0=1). Total deadlock.

> **📚 Teaching moment — Rolling update math**
>
> `maxSurge` and `maxUnavailable` define the update bandwidth:
> - `maxSurge: 1, maxUnavailable: 0` — safe update: create 1 extra pod, then kill 1 old one. Needs spare capacity.
> - `maxSurge: 0, maxUnavailable: 1` — in-place replacement: kill 1 old, create 1 new. Momentary capacity drop.
> - `maxSurge: 0, maxUnavailable: 0` — **deadlock** for single-replica deployments.
>
> Default is `maxSurge: 25%, maxUnavailable: 25%`. Don't set both to 0.

---

## ACT II — The fix

```bash
kubectl patch deployment api -n production \
  -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":1,"maxUnavailable":0}}}}'
```

Rollout immediately proceeds:

```bash
kubectl rollout status deployment/api -n production
```

```
Waiting for deployment "api" rollout to finish: 1 out of 1 new replicas have been updated...
deployment "api" successfully rolled out
```

---

## EPILOGUE

*"maxUnavailable:0 and maxSurge:0 is a paradox. The deployment wants to update but can neither add nor remove pods. It waits forever. Never set both to zero."*

> **Inspector Ahmed's Rule #31:** Rollout stuck with no new pods starting? Check `kubectl describe deployment` Strategy. If maxSurge and maxUnavailable are both 0, that's your deadlock.
