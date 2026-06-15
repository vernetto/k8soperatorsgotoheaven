# Episode 17 — "The Forgotten Namespace"
### *Inspector Ahmed and the secret that exists but can't be found*

**Culprit:** Secret exists in the wrong namespace — pods can only read secrets in their own namespace
**Difficulty:** ⭐ Beginner
**Tags:** `namespace` `secrets` `configmap` `isolation`

---

## OPENING — Crime scene

"The secret was there. Ahmed could see it. The developer could see it. But the pod couldn't find it. It was like looking at a key through a glass wall — visible, unreachable."

```bash
kubectl get secret db-credentials
```

```
NAME              TYPE     DATA   AGE
db-credentials    Opaque   2      5d
```

The secret exists. The pod is crashing with:

```
Error: secret "db-credentials" not found
```

---

## ACT I — The glass wall

```bash
kubectl get secret db-credentials
# This runs in the default context namespace
```

Ahmed checks which namespace the pod is in:

```bash
kubectl get pod api-server-7f9d-xk2p -n production
```

Now he checks the secret's namespace:

```bash
kubectl get secret db-credentials -n production
```

```
Error from server (NotFound): secrets "db-credentials" not found
```

The secret is in the `default` namespace. The pod is in `production`. Kubernetes namespace isolation means a pod can only reference Secrets in its own namespace.

> **📚 Teaching moment — Namespace isolation**
>
> Namespaces are Kubernetes's isolation boundary for most resources. Pods can only mount Secrets and ConfigMaps from their own namespace. They cannot reference resources across namespaces directly.
>
> This is intentional: it prevents a pod in `development` from accidentally mounting production secrets.
>
> The fix is always: create the Secret in the namespace where the pod lives. Never move pods to where the Secret is.

---

## ACT II — The fix

```bash
# Copy the secret to the correct namespace
kubectl get secret db-credentials -o yaml \
  | grep -v '^\s*namespace:' \
  | kubectl apply -n production -f -
```

Or, better — use a secrets management tool (External Secrets Operator, Vault) that syncs secrets into the correct namespace automatically, so this never happens again.

```bash
kubectl get secret db-credentials -n production
```

```
NAME              TYPE     DATA   AGE
db-credentials    Opaque   2      5s
```

---

## EPILOGUE

*"Namespaces are walls. Secrets don't cross walls. When a pod can't find a secret that clearly exists, check the namespace. The answer is always there."*

> **Inspector Ahmed's Rule #17:** Secret not found = wrong namespace. Always run `kubectl get secret <name> -n <pod-namespace>`. The `-n` flag is your best friend.
