# Episode 94 — "The Zombie Namespace"
### *Inspector Ahmed and the namespace full of terminating resources*

**Culprit:** Multiple resources with stale finalizers block namespace deletion
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `namespace` `finalizer` `terminating` `cleanup` `operators`

---

## OPENING — Crime scene

"An old project namespace had been marked for deletion. `kubectl delete namespace old-project` — run two weeks ago. The namespace was still there. Still Terminating. A graveyard."

```bash
kubectl get namespace old-project
```

```
NAME          STATUS        AGE
old-project   Terminating   14d
```

---

## ACT I — Cataloguing the stuck resources

```bash
kubectl api-resources --verbs=list --namespaced -o name | \
  xargs -I{} kubectl get {} -n old-project \
  --ignore-not-found -o name 2>/dev/null | \
  grep -v "^$"
```

```
serviceaccounts/default
configmaps/kube-root-ca.crt
myoperator.io/v1alpha1/tasks/task-alpha
myoperator.io/v1alpha1/tasks/task-beta
monitoring.coreos.com/v1/prometheusrules/app-rules
monitoring.coreos.com/v1/servicemonitors/app-monitor
```

Multiple CRDs with stuck resources. Some from a deleted operator (myoperator.io), some from Prometheus Operator.

---

## ACT II — Systematic finalizer removal

For each stuck resource, remove its finalizers:

```bash
# Remove finalizers from all myoperator tasks
kubectl get tasks -n old-project -o name | \
  xargs -I{} kubectl patch {} -n old-project \
  --type=json \
  -p='[{"op":"remove","path":"/metadata/finalizers"}]'

# Remove finalizers from Prometheus resources
kubectl get prometheusrules -n old-project -o name | \
  xargs -I{} kubectl patch {} -n old-project \
  --type=json \
  -p='[{"op":"remove","path":"/metadata/finalizers"}]'

kubectl get servicemonitors -n old-project -o name | \
  xargs -I{} kubectl patch {} -n old-project \
  --type=json \
  -p='[{"op":"remove","path":"/metadata/finalizers"}]'
```

If the CRDs themselves are gone and the resources can't be addressed via normal kubectl:

```bash
# Nuclear option: clear namespace finalizers directly via the API
kubectl get namespace old-project -o json \
  | python3 -c "import json,sys; ns=json.load(sys.stdin); ns['spec']['finalizers']=[]; print(json.dumps(ns))" \
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

*"A namespace stuck Terminating for more than 5 minutes has resources with finalizers and no controller to clear them. Find every stuck resource, patch out its finalizers, and the namespace will self-delete. Prevention: decommission operators before deleting their namespaces."*

> **Inspector Ahmed's Rule #94:** Namespace Terminating for days? List all resources inside it. For each one with a finalizer, patch it to remove the finalizer. The namespace clears itself once all resources are gone. Use the raw API finalize endpoint as last resort.
