# Episode 97 — "The Service Account Token Thief"
### *Inspector Ahmed and the pod that reads other pods' secrets*

**Culprit:** Default ServiceAccount automountServiceAccountToken not disabled — all pods get API access by default
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `serviceaccount` `security` `automount` `rbac` `least-privilege`

---

## OPENING — Crime scene

"A security pen test found that any compromised pod in the cluster could use its automatically mounted ServiceAccount token to list all Secrets in the cluster. The default ServiceAccount had been silently given cluster-wide read access — by accident."

```bash
# From inside any random pod in production namespace
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
APISERVER=https://kubernetes.default.svc

curl -k -H "Authorization: Bearer $TOKEN" \
  $APISERVER/api/v1/secrets
```

```json
{
  "kind": "SecretList",
  "items": [
    {"metadata": {"name": "db-credentials", "namespace": "production"}, ...},
    {"metadata": {"name": "api-keys", "namespace": "production"}, ...}
  ]
}
```

Any pod — including a compromised one — can read all secrets in the namespace using its auto-mounted token.

---

## ACT I — The problem

By default, every pod gets a ServiceAccount token automatically mounted at `/var/run/secrets/kubernetes.io/serviceaccount/token`. Most application pods don't need to call the Kubernetes API — but they get credentials anyway.

Additionally, someone had created a ClusterRoleBinding giving the `default` ServiceAccount in `production` namespace read access to secrets — probably to solve a quick problem without thinking about the blast radius.

> **📚 Teaching moment — Least privilege for ServiceAccounts**
>
> Two layers of hardening:
>
> 1. **Disable automount** for pods that don't need API access:
> ```yaml
> # In the ServiceAccount:
> automountServiceAccountToken: false
>
> # Or per-pod:
> spec:
>   automountServiceAccountToken: false
> ```
>
> 2. **Never give the default ServiceAccount permissions**: create dedicated ServiceAccounts with exactly the permissions each application needs. The `default` ServiceAccount should have no RBAC bindings.
>
> Kubernetes 1.24+ no longer creates long-lived tokens automatically — but projected tokens are still mounted unless you opt out.

---

## ACT II — Hardening

```bash
# Disable automount on the default ServiceAccount
kubectl patch serviceaccount default -n production \
  -p '{"automountServiceAccountToken": false}'

# Remove the over-permissive ClusterRoleBinding
kubectl delete clusterrolebinding default-sa-secret-reader

# For pods that genuinely need API access, create dedicated ServiceAccounts
kubectl create serviceaccount api-operator -n production
```

Verify no pods can now reach secrets:

```bash
kubectl exec api-7f9d4b-xk2p -n production -- \
  ls /var/run/secrets/kubernetes.io/serviceaccount/
```

```
ls: /var/run/secrets/kubernetes.io/serviceaccount/: No such file or directory
```

Token no longer mounted. Blast radius of a compromised pod reduced to zero.

---

## EPILOGUE

*"Every pod gets an API token by default. Most pods don't need it. Disable automountServiceAccountToken on the default ServiceAccount in every namespace. Never give the default ServiceAccount RBAC permissions. Create dedicated ServiceAccounts for what actually needs API access."*

> **Inspector Ahmed's Rule #97:** Disable `automountServiceAccountToken` on the `default` ServiceAccount in every namespace. Create dedicated ServiceAccounts only for pods that genuinely need Kubernetes API access. Audit RBAC bindings on default ServiceAccounts.
