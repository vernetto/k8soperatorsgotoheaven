# Episode 18 — "The Broken Ladder"
### *Inspector Ahmed and the init container that never finishes*

**Culprit:** Init container stuck waiting for a service that doesn't exist yet
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `init-containers` `dependency` `pending` `startup-order`

---

## OPENING — Crime scene

"The pod had been `Init:0/1` for thirty minutes. The main container never started. Nobody had noticed because nobody had bothered to check what init containers were doing."

```bash
kubectl get pods -n production
```

```
NAME                     READY   STATUS     RESTARTS   AGE
api-7f9d4b-xk2p          0/1     Init:0/1   0          31m
```

`Init:0/1` — the pod has 1 init container and it has completed 0. The main container hasn't started.

---

## ACT I — The stuck ladder

```bash
kubectl describe pod api-7f9d4b-xk2p -n production
```

```
Init Containers:
  wait-for-db:
    State:    Running
    Started:  31m ago
    Image:    busybox:1.36
    Command:  ["/bin/sh", "-c"]
    Args:     ["until nc -z postgres-service 5432; do sleep 2; done"]
```

The init container is running an `nc` (netcat) loop, trying to reach `postgres-service` on port 5432. It loops every 2 seconds until the connection succeeds.

```bash
kubectl logs api-7f9d4b-xk2p -n production -c wait-for-db
```

```
(no output — the loop is just sleeping and retrying silently)
```

```bash
kubectl get svc postgres-service -n production
```

```
Error from server (NotFound): services "postgres-service" not found
```

The service doesn't exist. The init container will loop forever.

> **📚 Teaching moment — Init containers**
>
> Init containers run to completion *before* the main containers start. They run in sequence, one after another. If an init container fails or never completes, the pod stays in `Init:N/M` forever.
>
> Common uses: wait for a dependency to be ready, run database migrations, inject configuration files. They're powerful — but if the dependency they're waiting for doesn't exist, they become a silent infinite loop.

---

## ACT II — Diagnosing and fixing

The PostgreSQL service was supposed to be deployed first. It wasn't — a Helm dependency was missing. Ahmed checks:

```bash
kubectl get all -n production | grep postgres
```

```
(nothing)
```

PostgreSQL was never deployed to this namespace. Ahmed deploys it:

```bash
helm install postgres bitnami/postgresql -n production \
  --set auth.database=appdb \
  --set auth.username=appuser \
  --set auth.password=REDACTED
```

Within seconds, the init container's `nc` call succeeds, it exits 0, and the main container starts.

```bash
kubectl get pods -n production
```

```
NAME                     READY   STATUS    RESTARTS   AGE
api-7f9d4b-xk2p          1/1     Running   0          32m
```

---

## EPILOGUE

*"Init:0/1 means 'I'm waiting for something.' The question is: does that something exist? Always check the init container logs and verify that what it's waiting for is actually deployed."*

> **Inspector Ahmed's Rule #18:** `Init:0/1` pod = check init container logs. Verify the dependency it's waiting for actually exists. `kubectl get svc` and `kubectl get pods` in the same namespace.
