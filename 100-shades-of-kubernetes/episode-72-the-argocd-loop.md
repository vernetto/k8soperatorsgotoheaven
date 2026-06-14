# Episode 72 — "The ArgoCD Loop"
### *Inspector Ahmed and the application that is always out of sync*

**Culprit:** ArgoCD self-heal loop — application generates dynamic fields that cause perpetual drift
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `argocd` `gitops` `sync` `drift` `annotations`

---

## OPENING — Crime scene

"The ArgoCD application was always OutOfSync. Auto-sync was enabled — so it kept syncing every minute. Every sync triggered a rollout. The cluster was in constant motion for no reason, using resources and generating noise."

```bash
argocd app get production-api
```

```
Name:    production-api
Status:  OutOfSync
Health:  Healthy

GROUP  KIND        NAMESPACE   NAME   STATUS     HEALTH
apps   Deployment  production  api    OutOfSync  Healthy
```

Sync every 3 minutes. Always OutOfSync. Always Healthy.

---

## ACT I — What's drifting?

```bash
argocd app diff production-api
```

```diff
--- a/apps/api/deployment.yaml
+++ b/apps/api/deployment.yaml (live)
@@ -4,6 +4,8 @@
   annotations:
+    deployment.kubernetes.io/revision: "47"
+    kubectl.kubernetes.io/last-applied-configuration: |
+      {"apiVersion":"apps/v1",...}
```

The diff shows only Kubernetes-managed annotations that are added automatically at runtime. The `deployment.kubernetes.io/revision` annotation is updated by Kubernetes after every rollout. ArgoCD sees this as drift from the git state (which has no such annotation), syncs, which triggers a new rollout, which increments the revision, which causes drift again. Infinite loop.

> **📚 Teaching moment — ArgoCD ignoreDifferences**
>
> Some Kubernetes resources have fields that are managed at runtime and will always differ from the git source. Common examples:
> - `deployment.kubernetes.io/revision` — updated by Kubernetes after every rollout
> - `kubectl.kubernetes.io/last-applied-configuration` — added by kubectl apply
> - `status` fields
> - Admission webhook-injected fields (e.g., `injectionTimestamp`)
>
> ArgoCD's `ignoreDifferences` config tells it to ignore specific fields when comparing live vs git state.

---

## ACT II — Configure ignoreDifferences

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: production-api
spec:
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /metadata/annotations/deployment.kubernetes.io~1revision
    - /metadata/annotations/kubectl.kubernetes.io~1last-applied-configuration
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
```

After applying:

```bash
argocd app get production-api
```

```
Status:  Synced
Health:  Healthy
```

The perpetual sync loop stops.

---

## EPILOGUE

*"If ArgoCD is perpetually OutOfSync despite selfHeal, the diff is caused by runtime-managed fields, not real drift. Use ignoreDifferences to exclude annotation fields that Kubernetes manages automatically. Don't fight the system — configure around it."*

> **Inspector Ahmed's Rule #72:** ArgoCD app perpetually OutOfSync but Healthy? The diff is caused by runtime-managed fields. Use `ignoreDifferences` with `jsonPointers` to exclude them. Check `argocd app diff` to identify exactly which fields.
