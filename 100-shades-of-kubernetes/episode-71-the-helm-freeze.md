# Episode 71 — "The Helm Freeze"
### *Inspector Ahmed and the upgrade that refuses to apply*

**Culprit:** Helm upgrade fails because of an immutable field change in a resource
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `helm` `upgrade` `immutable` `deployment` `labels`

---

## OPENING — Crime scene

"A routine Helm upgrade. Three lines of config changed. The `helm upgrade` command printed an error and exited. The release was left in a `pending-upgrade` state — and now even a rollback wouldn't work."

```bash
helm upgrade api ./charts/api -n production
```

```
Error: UPGRADE FAILED: cannot patch "api" with kind Deployment:
  Deployment.apps "api" is invalid:
  spec.selector: Invalid value:
  v1.LabelSelector{MatchLabels:map[string]string{"app":"api","version":"v2"}}:
  field is immutable
```

`field is immutable`. The Helm chart changed the `spec.selector` on the Deployment. Selectors are immutable after creation in Kubernetes.

---

## ACT I — The immutable selector

```bash
helm get manifest api -n production | grep -A 10 "selector:"
```

```yaml
selector:
  matchLabels:
    app: api
    # no version label in old release
```

```bash
# New chart version adds a version label to the selector:
# selector:
#   matchLabels:
#     app: api
#     version: v2    ← this addition makes it immutable conflict
```

The new chart added a `version` label to the Deployment selector. In Kubernetes, `spec.selector` on a Deployment is immutable — once created, it cannot be changed. Helm tries to patch the existing Deployment and the API server rejects it.

> **📚 Teaching moment — Immutable fields in Kubernetes**
>
> Several fields are immutable after creation:
> - `spec.selector` on Deployment, StatefulSet, DaemonSet
> - `spec.clusterIP` on Services
> - `spec.storageClassName` on PVCs
> - `spec.volumeName` on PVCs
> - Pod specs on running pods (most fields)
>
> When Helm tries to `kubectl apply` a change to an immutable field, the API server rejects it. Helm marks the release as `pending-upgrade`, which can block subsequent operations.

---

## ACT II — Recovery

```bash
# Check release status
helm status api -n production
```

```
STATUS: pending-upgrade
```

```bash
# Force rollback to previous good release
helm rollback api -n production --force
```

If rollback also fails because of the immutable field:

```bash
# Delete and recreate the deployment (brief downtime or with blue/green)
kubectl delete deployment api -n production
helm upgrade api ./charts/api -n production --force
```

For zero-downtime: use `kubectl replace --force` which deletes and recreates atomically (but has a brief window of zero replicas).

**Prevention — revert the selector change in the chart:**

```yaml
# Keep the original selector — never change it after first deploy
selector:
  matchLabels:
    app: api
    # Don't add new labels here — ever
```

If you genuinely need a new label in the selector, it requires a new Deployment name or a deployment strategy with rename + parallel run.

---

## EPILOGUE

*"Never change spec.selector in a Deployment chart after it's been applied to production. It is immutable. The only clean fix is delete and recreate. Design your label selectors carefully from day one — they are permanent."*

> **Inspector Ahmed's Rule #71:** `Helm upgrade failed: field is immutable`? The chart changed a selector, clusterIP, or other immutable field. Rollback to previous chart version. If stuck in pending-upgrade: `helm rollback --force`. Never change spec.selector after first deployment.
