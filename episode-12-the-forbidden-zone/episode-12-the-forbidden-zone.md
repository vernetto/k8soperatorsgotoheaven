# Episode 12 — "The Forbidden Zone"
### *Inspector Ahmed and the pod that can't access the API server*

**Culprit:** RBAC — ServiceAccount missing permissions
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `rbac` `serviceaccount` `permissions` `403` `authorization`

---

## OPENING — Crime scene

"The operator pod was running perfectly. It watched for CustomResources, reconciled state, managed other pods. Until someone 'hardened' the cluster's RBAC. Now the operator logged one thing on startup, then went silent."

```bash
kubectl logs operator-7f9d4b-xk2p -n operators
```

```
[INFO]  Operator started, watching namespace: production
[ERROR] Failed to list Deployments: deployments.apps is forbidden:
        User "system:serviceaccount:operators:operator-sa"
        cannot list resource "deployments" in API group "apps"
        in the namespace "production"
[FATAL] Cannot initialise controller. Exiting.
```

403 Forbidden from the Kubernetes API. The operator's ServiceAccount doesn't have permission to list Deployments.

---

## ACT I — The identity check

```bash
kubectl get pod operator-7f9d4b-xk2p -n operators -o yaml | grep serviceAccountName
```

```
  serviceAccountName: operator-sa
```

```bash
kubectl get serviceaccount operator-sa -n operators
```

```
NAME          SECRETS   AGE
operator-sa   0         2d
```

The ServiceAccount exists. Ahmed checks what permissions it has:

```bash
kubectl auth can-i list deployments \
  --as=system:serviceaccount:operators:operator-sa \
  -n production
```

```
no
```

```bash
kubectl auth can-i --list \
  --as=system:serviceaccount:operators:operator-sa \
  -n production
```

```
Resources                          Verbs
pods                               [get list watch]
```

The ServiceAccount can only read pods. Nothing else. Someone deleted its ClusterRole binding during the hardening exercise.

> **📚 Teaching moment — RBAC components**
>
> Kubernetes RBAC has four key objects:
> - **Role**: permissions within a namespace
> - **ClusterRole**: permissions cluster-wide or reusable across namespaces
> - **RoleBinding**: assigns a Role to a Subject (user, group, or ServiceAccount) within a namespace
> - **ClusterRoleBinding**: assigns a ClusterRole to a Subject cluster-wide
>
> The `kubectl auth can-i` command is Ahmed's favourite RBAC diagnostic tool. You can impersonate any ServiceAccount with `--as=`.

---

## ACT II — Reconstructing the permissions

Ahmed checks the operator's documentation to understand what it needs, then creates the appropriate Role and RoleBinding:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: operator-role
  namespace: production
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: operator-rolebinding
  namespace: production
subjects:
- kind: ServiceAccount
  name: operator-sa
  namespace: operators
roleRef:
  kind: Role
  name: operator-role
  apiGroup: rbac.authorization.k8s.io
