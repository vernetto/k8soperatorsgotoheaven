# Episode 49 — "The Forgotten Finalizer"
### *Inspector Ahmed and the namespace that never terminates*

**Culprit:** Namespace stuck in Terminating — resource with a finalizer from a deleted CRD
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `namespace` `finalizer` `crd` `terminating` `cleanup`

---

## OPENING — Crime scene

"The decommissioning checklist was complete. Deployments deleted. Services deleted. PVCs deleted. `kubectl delete namespace old-project` — issued three days ago. Status: Terminating. Still."

```bash
kubectl get namespace old-project
```

```
NAME          STATUS        AGE
old-project   Terminating   3d
```

Three days stuck. The namespace can't be deleted.

---

## ACT I — The hidden prisoner

```bash
kubectl api-resources --verbs=list --namespaced -o name | \
  xargs -I {} kubectl get {} --ignore-not-found \
  -n old-project -o name 2>/dev/null
```

```
serviceaccounts/default
configmaps/kube-root-ca.crt
myoperator.io/v1alpha1/myoperatortask/stuck-task
```

A custom resource `myoperatortask/stuck-task` from a CRD that was deleted months ago. The resource has a finalizer:

```bash
kubectl get myoperatortask stuck-task -n old-project -o yaml | grep finalizer
```

```
  finalizers:
  - myoperator.io/cleanup
```

The operator that would process this finalizer is gone. The CRD is gone. The finalizer will never be processed. The resource will never be deleted. The namespace will never terminate.

> **📚 Teaching moment — Namespace stuck Terminating**
>
> A namespace can't be deleted until all resources inside it are deleted. Resources with finalizers can't be deleted until their finalizers are removed. If the controller that handles a finalizer is gone, the finalizer is never removed — and the namespace is stuck forever.
>
> This is the most common cause of namespace stuck in Terminating.

---

## ACT II — Removing the orphaned finalizer

```bash
kubectl patch myoperatortask stuck-task -n old-project \
  --type='json' \
  -p='[{"op":"remove","path":"/metadata/finalizers"}]'
```

If the CRD is completely gone and kubectl can't address the resource, use the API directly:

```bash
kubectl get namespace old-project -o json \
  | jq '.spec.finalizers = []' \
  | kubectl replace --raw /api/v1/namespaces/old-project/finalize -f -
```

```bash
kubectl get namespace old-project
```

```
Error from server (NotFound): namespaces "old-project" not found
```

Gone.

---

## EPILOGUE

*"A namespace stuck Terminating has something inside it with a finalizer and no controller to clear it. Find the resource. Remove the finalizer manually. Then the namespace disappears. When decommissioning operators, always clean up CRs before uninstalling the CRD."*

> **Inspector Ahmed's Rule #49:** Namespace stuck Terminating for more than a few minutes? List all resources inside it including CRDs. Find the one with a finalizer. Remove the finalizer manually.
