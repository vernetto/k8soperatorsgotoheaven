# Episode 89 — "The Invisible Finalizer"
### *Inspector Ahmed and the CRD that can't be deleted*

**Culprit:** CRD deletion blocked by existing Custom Resources in other namespaces
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `crd` `customresource` `finalizer` `cleanup` `operators`

---

## OPENING — Crime scene

"The operator was being decommissioned. Helm uninstall ran cleanly. But the CRD stayed. `kubectl delete crd` hung. The CRD was protecting itself."

```bash
kubectl delete crd myoperatortasks.myoperator.io
```

```
customresourcedefinition.apiextensions.k8s.io "myoperatortasks.myoperator.io" deleted
```

Wait — that returned immediately. But:

```bash
kubectl get crd myoperatortasks.myoperator.io
```

```
NAME                         CREATED AT
myoperatortasks.myoperator.io   2023-09-01T10:00:00Z
```

Still there. Stuck in deletion.

```bash
kubectl get crd myoperatortasks.myoperator.io -o yaml | grep finalizer
```

```
  finalizers:
  - customresourcecleanup.apiextensions.k8s.io
```

The CRD has a finalizer that waits for all Custom Resources of this type to be deleted before the CRD itself is removed.

---

## ACT I — Finding all CRs

```bash
kubectl get myoperatortasks --all-namespaces
```

```
NAMESPACE     NAME          AGE
production    task-one      45d
staging       task-two      30d
old-project   task-three    90d
```

Three Custom Resources across three namespaces. All need to be deleted before the CRD will go.

```bash
kubectl delete myoperatortasks --all --all-namespaces
```

```bash
kubectl get crd myoperatortasks.myoperator.io
```

```
Error from server (NotFound): customresourcedefinitions
  "myoperatortasks.myoperator.io" not found
```

CRD deleted cleanly.

> **📚 Teaching moment — CRD deletion and CR cleanup**
>
> Kubernetes protects against orphaning data: a CRD can't be deleted while Custom Resources of that type exist anywhere in the cluster. This is enforced via the `customresourcecleanup.apiextensions.k8s.io` finalizer on the CRD.
>
> When decommissioning an operator:
> 1. Delete all Custom Resources (`kubectl delete <cr> --all --all-namespaces`)
> 2. Then delete the CRD (`kubectl delete crd <name>`)
> 3. Then uninstall the operator
>
> Order matters. Uninstalling the operator first (which deletes its CRD) while CRs exist leaves orphaned objects that can only be cleaned up by patching the CRD back in and then deleting CRs.

---

## EPILOGUE

*"CRDs protect their Custom Resources. Delete all CRs across all namespaces before deleting the CRD. Order of decommissioning: CRs first, CRD second, operator last. Reverse that order and you create cleanup nightmares."*

> **Inspector Ahmed's Rule #89:** CRD stuck deleting? Find all Custom Resources of that type: `kubectl get <cr> --all-namespaces`. Delete them all. The CRD finalizer then clears automatically.
