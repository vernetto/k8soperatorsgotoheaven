# Episode 16 — "The Unresponsive Witness"
### *Inspector Ahmed and the readiness probe that lies*

**Culprit:** Readiness probe endpoint returns 200 before the app is actually ready
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `readiness-probe` `rolling-update` `traffic` `502` `health-check`

---

## OPENING — Crime scene

"Every deployment was followed by two minutes of 502 errors. The new pods passed their readiness checks and received traffic. But they weren't actually ready — they just said they were. Users got half-initialised responses."

```bash
kubectl rollout status deployment/api -n production
```

```
deployment "api" successfully rolled out
```

Deployment succeeded. But the monitoring showed 502s for 90 seconds after every deploy.

---

## ACT I — The lying probe

```bash
kubectl get deployment api -n production -o yaml | grep -A 10 "readinessProbe"
```

```yaml
readinessProbe:
  httpGet:
    path: /ping
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

The readiness probe hits `/ping`. Ahmed checks what `/ping` does:

```bash
kubectl exec api-7f9d4b-xk2p -n production -- curl -s http://localhost:8080/ping
```

```
pong
```

The `/ping` endpoint returns 200 immediately — even before the app has loaded its configuration, warmed its cache, and established its database connection pool. It's a pure liveness check, not a readiness check.

> **📚 Teaching moment — What readiness should actually check**
>
> A readiness probe should answer: *"Is this instance ready to serve production traffic?"*
> That means checking:
> - Database connection is established and accepting queries
> - Cache is warmed (if your app uses a local cache)
> - Configuration is fully loaded
> - Any dependent services are reachable
>
> A `/ping` that just returns `pong` is a liveness check. It tells you the process is alive — not that it's ready.

---

## ACT II — The proper readiness endpoint

The team adds a `/ready` endpoint to the application:

```javascript
app.get('/ready', async (req, res) => {
  try {
    await db.query('SELECT 1');          // DB connection alive?
    if (!cache.isWarmed()) {             // Cache ready?
      return res.status(503).json({ status: 'warming' });
    }
    res.json({ status: 'ready' });
  } catch (err) {
    res.status(503).json({ status: 'not ready', error: err.message });
  }
});
```

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 6
```

Next deployment: zero 502 errors. Pods only receive traffic after the DB connection is confirmed and cache is warm.

---

## EPILOGUE

*"A readiness probe that always returns 200 is worse than no probe. It tells the load balancer a lie — that the pod is ready — and the users pay for it with errors. Make your /ready endpoint actually check readiness."*

> **Inspector Ahmed's Rule #16:** If you see 502s after every deploy, your readiness probe isn't checking the right things. Make it verify DB connections and cache state — not just that the process is alive.
