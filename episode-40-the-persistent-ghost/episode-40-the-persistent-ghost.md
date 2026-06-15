# Episode 40 — "The Persistent Ghost"
### *Inspector Ahmed and the PVC that can't be deleted*

**Culprit:** PVC stuck in Terminating due to a finalizer — a pod still holds a reference
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `pvc` `finalizer` `terminating` `storage` `volumes`

---

## OPENING — Crime scene

"The team was cleaning up a decommissioned service. Pods: deleted. Deployment: deleted. Service: deleted. PVC: Terminating. For two hours. Terminating. Forever."

```bash
kubectl get pvc -n staging
```

```
NAME              STATUS        VOLUME   CAPACITY   AGE
data-old-app      Terminating            50Gi       47d
```

The PVC is stuck in `Terminating`. The volume it provisioned is still occupying cloud storage — and billing.

---

## ACT I — The finalizer

```bash
kubectl get pvc data-old-app -n staging -o yaml | grep finalizer
```

```
  finalizers:
  - kubernetes.io/pvc-protection
```

The `kubernetes.io/pvc-protection` finalizer is set by Kubernetes automatically on every PVC. It prevents deletion while the PVC is still mounted by a running pod. Kubernetes will only remove the finalizer (and complete deletion) once no pods reference the PVC.

```bash
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName == "data-old-app") | .metadata.name + " (" + .metadata.namespace + ")"'
```

```
old-app-migration-job (staging)
```

A job pod from a migration run last week is still running — and still mounting the PVC.

---

## ACT II — The fix

```bash
kubectl delete job old-app-migration-job -n staging
```

Once the job pod terminates, the PVC finalizer is removed automatically:

```bash
kubectl get pvc -n staging
```

```
No resources found in staging namespace.
```

> **⚠️ Nuclear option (use only when certain no pod is mounting the PVC):**
>
> If the pod reference is truly gone but the finalizer is stuck:
> ```bash
> kubectl patch pvc data-old-app -n staging \
>   -p '{"metadata":{"finalizers":[]}}' \
>   --type=merge
> ```
> This removes the finalizer manually, allowing deletion to complete. Only do this if you're sure no pod is using it — removing the finalizer while a pod has the volume mounted can cause data corruption.

---

## EPILOGUE

*"PVC stuck Terminating = something is still mounted. Find that pod. Delete it or wait for it to finish. The finalizer mechanism exists to prevent accidental data loss. Respect it."*

> **Inspector Ahmed's Rule #40:** PVC stuck Terminating = `kubernetes.io/pvc-protection` finalizer. Find the pod mounting it with a jq query. Delete the pod. PVC deletion completes automatically.
