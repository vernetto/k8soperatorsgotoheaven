# Episode 61 — "The Operator Storm"
### *Inspector Ahmed and the reconciliation loop that spins forever*

**Culprit:** Operator reconciliation loop triggered by its own changes — infinite reconcile storm
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `operator` `controller` `reconciliation` `cpu` `custom-resource`

---

## OPENING — Crime scene

"The operator pod was consuming 3 CPU cores continuously. The API server was flooded with requests. Every reconcile triggered another update which triggered another reconcile. An infinite loop disguised as 'working.'"

```bash
kubectl top pod -n operators
```

```
NAME                      CPU(cores)   MEMORY(bytes)
myoperator-7f9d4b-xk2p    2950m        256Mi
```

Nearly 3 full CPU cores. For a controller that should be mostly idle.

```bash
kubectl logs myoperator-7f9d4b-xk2p -n operators | tail -20
```

```
2024/03/14 10:22:14 Reconciling MyResource/production/my-app
2024/03/14 10:22:14 Updating status on MyResource/production/my-app
2024/03/14 10:22:14 Reconciling MyResource/production/my-app
2024/03/14 10:22:14 Updating status on MyResource/production/my-app
2024/03/14 10:22:14 Reconciling MyResource/production/my-app
```

Reconciling 30 times per second. The operator updates the resource status, which triggers a watch event, which triggers another reconcile.

> **📚 Teaching moment — Operator reconciliation loops**
>
> Kubernetes operators use the controller pattern: watch for changes to resources, reconcile the desired state with the actual state. The key requirement: **reconciliation must be idempotent**.
>
> A common bug: the operator modifies the resource's `status` or `metadata` during reconciliation, which triggers a new watch event, which triggers another reconciliation — infinitely.
>
> The fix: use `status` subresource updates (which don't trigger spec watches), or check if the current state already matches desired state before updating, or use `Generation` field to detect real spec changes vs status-only updates.

---

## ACT II — The idempotency fix

The operator code is updated to check if an update is actually needed:

```go
// Before update, check if status already matches desired state
if currentStatus == desiredStatus {
    return reconcile.Result{}, nil  // nothing to do, don't update
}
// Only update if there's a real change
if err := r.Status().Update(ctx, resource); err != nil {
    return reconcile.Result{}, err
}
```

Also use the `status` subresource endpoint for status updates, which doesn't trigger spec-watch events:

```go
// Use Status().Update() not Update() for status changes
r.Status().Update(ctx, resource)
// NOT: r.Update(ctx, resource)
```

CPU drops to < 10m. Reconcile rate: a few times per minute as intended.

---

## EPILOGUE

*"An operator that reconciles itself to death has a non-idempotent reconcile function. Every state change it makes should be checked against current state first. If already in desired state, return immediately. Don't update what hasn't changed."*

> **Inspector Ahmed's Rule #61:** Operator consuming high CPU with rapid reconcile log entries? Infinite reconciliation loop. Check: does the reconcile update status unconditionally? Add a 'is current state == desired state?' check. Return early if no change needed.
