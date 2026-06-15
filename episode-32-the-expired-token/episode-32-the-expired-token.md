# Episode 32 — "The Expired Token"
### *Inspector Ahmed and the pod that can't talk to the registry*

**Culprit:** imagePullSecret expired — registry credentials rotated but not updated
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `imagepullsecret` `registry` `authentication` `credentials`

---

## OPENING — Crime scene

"The cluster had been pulling images from the private registry for months. Then one day, every pod deploy started failing with authentication errors. The registry was up. The images were there. But Kubernetes couldn't get them."

```bash
kubectl describe pod api-7f9d4b-xk2p -n production
```

```
Events:
  Warning  Failed  2m  kubelet
    Failed to pull image "registry.company.com/api:v3.2.1":
    unauthorized: authentication required
```

`unauthorized`. The credentials are wrong or expired.

---

## ACT I — The pull secret

```bash
kubectl get pod api-7f9d4b-xk2p -n production -o yaml | grep imagePullSecrets -A 3
```

```yaml
imagePullSecrets:
- name: registry-credentials
```

```bash
kubectl get secret registry-credentials -n production
```

```
NAME                    TYPE                             DATA   AGE
registry-credentials    kubernetes.io/dockerconfigjson   1      365d
```

**Age: 365 days.** The secret is a year old. The registry team rotated credentials 2 days ago — the old credentials expired, and the Kubernetes secret was never updated.

---

## ACT II — Updating the secret

```bash
# Delete old secret
kubectl delete secret registry-credentials -n production

# Create new one with updated credentials
kubectl create secret docker-registry registry-credentials \
  --docker-server=registry.company.com \
  --docker-username=k8s-puller \
  --docker-password=NEW_TOKEN_HERE \
  --docker-email=devops@company.com \
  -n production
```

Trigger a rollout to force the pods to re-pull:

```bash
kubectl rollout restart deployment/api -n production
```

> **📚 Teaching moment — imagePullSecrets scope**
>
> imagePullSecrets must exist in the same namespace as the pod. A secret in `default` won't work for pods in `production`.
>
> Best practice: add the imagePullSecret to the namespace's default ServiceAccount so you don't need to reference it in every deployment:
> ```bash
> kubectl patch serviceaccount default -n production \
>   -p '{"imagePullSecrets": [{"name": "registry-credentials"}]}'
> ```
> Any pod using the `default` ServiceAccount in that namespace will automatically use the pull secret.

---

## EPILOGUE

*"Registry credentials expire. Certificate tokens expire. API keys expire. Set a reminder 30 days before expiry — or better, automate credential rotation using External Secrets Operator or Vault."*

> **Inspector Ahmed's Rule #32:** `unauthorized` on image pull = expired or wrong pull credentials. Delete and recreate the imagePullSecret. Then add it to the default ServiceAccount so you don't have to reference it everywhere.
