# Episode 3 — "The Infinite Scream"
### *Inspector Ahmed and the pod that keeps dying*

**Culprit:** Missing environment variable causes app crash on startup
**Difficulty:** ⭐ Beginner
**Tags:** `crashloopbackoff` `environment-variables` `configmap` `secrets`

---

## OPENING — Crime scene

"Restarts: 47. The number blinked at Ahmed from the terminal like a neon sign outside a bad hotel. The pod was alive. Then dead. Then alive again. Then dead. It had been doing this for two hours. Nobody had read the logs."

```bash
kubectl get pods -n production
```

```
NAME                        READY   STATUS             RESTARTS   AGE
api-server-84d7f9-xp2kl     0/1     CrashLoopBackOff   47         2h
```

CrashLoopBackOff. The pod starts, crashes, Kubernetes restarts it, it crashes again. A loop with no exit. The backoff timer grows: 10s, 20s, 40s, 80s, 160s, capped at 5 minutes. That's why it's been broken for two hours and people only noticed now.

---

## ACT I — Reading the last words

When a pod crashes, it leaves a trace. Ahmed goes for it immediately.

```bash
kubectl logs api-server-84d7f9-xp2kl -n production
```

```
[ERROR] Configuration error: required environment variable DATABASE_URL is not set
[FATAL] Application cannot start without a database connection string.
Exiting.
```

Three lines. That's all the pod managed to output before dying.

> **📚 Teaching moment — Logs of a dead pod**
>
> `kubectl logs <pod>` shows logs from the *currently running* container. If the pod has already crashed and restarted, that container is gone — you need `--previous` to read the logs of the dead one:
> ```bash
> kubectl logs <pod> --previous
> ```
> Ahmed always checks both. The current one might have already progressed further before crashing again.

```bash
kubectl logs api-server-84d7f9-xp2kl -n production --previous
```

Same output. The pod dies in the same place every single time. It's not flaky — it's deterministic. Something is *always* missing.

---

## ACT II — Checking the environment

```bash
kubectl describe pod api-server-84d7f9-xp2kl -n production | grep -A 30 "Environment"
```

```
    Environment:
      APP_ENV:         production
      LOG_LEVEL:       info
      PORT:            8080
```

No `DATABASE_URL`. The variable simply isn't there. Ahmed checks the deployment spec to understand *why*.

```bash
kubectl get deployment api-server -n production -o yaml | grep -A 40 "env:"
```

```yaml
        env:
          - name: APP_ENV
            value: production
          - name: LOG_LEVEL
            value: info
          - name: PORT
            value: "8080"
          - name: DATABASE_URL
            valueFrom:
              secretKeyRef:
                name: api-secrets
                key: database-url
```

The deployment *expects* `DATABASE_URL` to come from a Secret called `api-secrets`, key `database-url`. Ahmed checks if the secret exists.

```bash
kubectl get secret api-secrets -n production
```

```
Error from server (NotFound): secrets "api-secrets" not found
```

There it is.

> **📚 Teaching moment — How env vars from Secrets work**
>
> When you use `secretKeyRef` in a pod spec, Kubernetes tries to mount the value at pod startup. If the Secret doesn't exist:
> - The pod **fails to start** entirely (status: `CreateContainerConfigError`)
> - OR if it manages to start but the app checks the var itself, it crashes immediately
>
> Common causes: the Secret was never created in this namespace, was deleted accidentally, or the deployment was copied to a new namespace without copying its Secrets.

---

## ACT III — The missing witness

Ahmed checks if the secret exists in another namespace:

```bash
kubectl get secret api-secrets --all-namespaces
```

```
NAMESPACE    NAME          TYPE     DATA   AGE
staging      api-secrets   Opaque   3      45d
```

There it is — in `staging`. Someone promoted the deployment manifest to production but forgot to create the corresponding Secret. A classic.

Ahmed does *not* just copy the staging secret directly. Staging credentials should never be used in production. He goes to the team's secrets manager (Vault, in this case) and pulls the production values.

```bash
# Create the secret with the correct production value
kubectl create secret generic api-secrets \
  --from-literal=database-url="postgresql://prod-user:REDACTED@prod-db.internal:5432/appdb" \
  -n production
```

---

## ACT IV — The arrest

**Presenting problem:** Pod in `CrashLoopBackOff`, application never starts.

**Root cause:** Deployment references Secret `api-secrets` which did not exist in the `production` namespace. App crashes immediately on startup when `DATABASE_URL` is not set.

```bash
kubectl get pods -n production -w
```

```
NAME                        READY   STATUS             RESTARTS   AGE
api-server-84d7f9-xp2kl     0/1     CrashLoopBackOff   47         2h
api-server-84d7f9-xp2kl     0/1     Error              47         2h
api-server-84d7f9-xp2kl     1/1     Running            47         2h1m
```

The pod restarts one more time — this time it finds `DATABASE_URL` — and stays up.

---

## EPILOGUE

*"Forty-seven restarts. Two hours of outage. One missing Secret. Read the logs first. Always. The application almost always tells you exactly what's wrong — if you bother to listen."*

> **📚 Episode takeaways**
>
> | Command | What it's for |
> |---|---|
> | `kubectl logs <pod>` | Current container logs |
> | `kubectl logs <pod> --previous` | Logs from the last crashed container |
> | `kubectl describe pod` → grep Environment | See which env vars are actually mounted |
> | `kubectl get secret --all-namespaces` | Find if the secret exists elsewhere |
>
> **Inspector Ahmed's Rule #3:** `CrashLoopBackOff` means the app itself is crashing. The answer is in the logs — not in Kubernetes events. Look there first.
