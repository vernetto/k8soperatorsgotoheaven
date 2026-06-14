# Episode 39 — "The Phantom Service Account"
### *Inspector Ahmed and the workload identity that doesn't exist*

**Culprit:** Pod uses a non-existent ServiceAccount — fails to start
**Difficulty:** ⭐ Beginner
**Tags:** `serviceaccount` `identity` `pod` `configuration`

---

## OPENING — Crime scene

"A new Helm chart was installed. The pods refused to start. The error wasn't about images or resources — it was about identity."

```bash
kubectl describe pod app-7f9d4b-xk2p -n production
```

```
Events:
  Warning  Failed  2m  kubelet
    Error: configmaps "app-7f9d4b-xk2p" is forbidden:
    pods "app-7f9d4b-xk2p" not found:
    error looking up service account production/app-service-account:
    serviceaccount "app-service-account" not found
```

The pod references ServiceAccount `app-service-account` which doesn't exist in the `production` namespace.

> **📚 Teaching moment — ServiceAccount auto-creation**
>
> Pods run as a ServiceAccount. If no `serviceAccountName` is specified, they use the `default` ServiceAccount in their namespace. If a specific ServiceAccount is specified and it doesn't exist, the pod fails to start with the error above.
>
> Helm charts often create the ServiceAccount as part of the chart — but if the chart was installed with `serviceAccount.create: false` (to use a pre-existing one), and the pre-existing one doesn't exist, you get this error.

---

## ACT II — Create the ServiceAccount

```bash
kubectl create serviceaccount app-service-account -n production
```

The pod starts immediately — Kubernetes retries pod creation and this time finds the ServiceAccount.

If the ServiceAccount needs specific RBAC permissions, add them:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-rolebinding
  namespace: production
subjects:
- kind: ServiceAccount
  name: app-service-account
  namespace: production
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
```

---

## EPILOGUE

*"ServiceAccount not found is one of the simplest errors in Kubernetes. The fix is one command. The lesson: when installing Helm charts with `serviceAccount.create: false`, always verify the ServiceAccount exists first."*

> **Inspector Ahmed's Rule #39:** Pod fails with 'serviceaccount not found'? Create it. One command: `kubectl create serviceaccount <name> -n <namespace>`. Then check if it needs RBAC permissions.
