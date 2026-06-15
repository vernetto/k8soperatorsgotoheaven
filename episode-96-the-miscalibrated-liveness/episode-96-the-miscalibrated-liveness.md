# Episode 96 — "The Miscalibrated Liveness"
### *Inspector Ahmed and the perfect pod that keeps restarting in production*

**Culprit:** Liveness probe timeout too short — slow response under load triggers unnecessary restarts
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `liveness-probe` `timeout` `load` `restarts` `production`

---

## OPENING — Crime scene

"The application had zero issues in staging. In production, under real traffic, it restarted every hour. Exactly every hour — like clockwork. The logs showed nothing wrong. The liveness probe disagreed."

```bash
kubectl describe pod api-7f9d4b-xk2p -n production
```

```
Events:
  Warning  Unhealthy  1h  kubelet
    Liveness probe failed:
    Get "http://10.244.2.14:8080/health": context deadline exceeded
    (Client.Timeout exceeded while awaiting headers)
  Warning  Killing    1h  kubelet
    Container api failed liveness probe, will be restarted
```

Timeout. The liveness probe timed out.

---

## ACT I — The probe vs load mismatch

```bash
kubectl get deployment api -n production -o yaml | grep -A 10 "livenessProbe"
```

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  timeoutSeconds: 1      ← 1 second timeout
  periodSeconds: 10
  failureThreshold: 3
```

`timeoutSeconds: 1`. The liveness probe must get a response within 1 second.

```bash
# Measure actual /health response time under load
kubectl exec api-7f9d4b-xk2p -n production -- \
  time curl -s http://localhost:8080/health
```

```
{"status":"ok"}
real    0m0.089s
```

89ms — well within 1 second. But this is at rest. Ahmed checks during a traffic peak:

```bash
kubectl exec api-7f9d4b-xk2p -n production -- \
  ab -n 100 -c 20 http://localhost:8080/api/data &  # simulate load
sleep 2
kubectl exec api-7f9d4b-xk2p -n production -- \
  time curl -s http://localhost:8080/health
```

```
{"status":"ok"}
real    0m1.823s
```

1.8 seconds under load. The `/health` endpoint queries the database — and under high concurrency, the database connection pool is exhausted, causing the health check to wait for a connection. Under peak traffic, it exceeds the 1-second timeout.

> **📚 Teaching moment — Probe timeouts under load**
>
> Liveness probe timeouts must account for worst-case response times, not average-case. Under production load, response times are higher.
>
> Best practices:
> - Set `timeoutSeconds` to at least 3-5x the observed average response time
> - Make `/health` a **dedicated lightweight endpoint** that doesn't touch the database (use `/ready` for that)
> - The liveness check should only verify "is the process alive and not deadlocked" — not "is it serving traffic efficiently" (that's readiness)
> - Increase `failureThreshold` to tolerate brief spikes: 3 × 10s = 30s before restart

---

## ACT II — The fix

**Fix 1 — Increase timeout:**

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  timeoutSeconds: 5      # allow 5 seconds
  periodSeconds: 10
  failureThreshold: 3
```

**Fix 2 — Decouple health from database** (proper fix):

```javascript
// /health — liveness: just checks the process is alive
app.get('/health', (req, res) => {
  res.json({ status: 'alive' });
});

// /ready — readiness: checks database connection
app.get('/ready', async (req, res) => {
  try {
    await db.query('SELECT 1');
    res.json({ status: 'ready' });
  } catch (e) {
    res.status(503).json({ status: 'not ready' });
  }
});
```

---

## EPILOGUE

*"A 1-second liveness timeout is fine in staging. Under production load, everything is slower. Set timeouts to cover worst-case response time, not best-case. And make /health a truly lightweight endpoint that doesn't touch any external dependencies."*

> **Inspector Ahmed's Rule #96:** Pod restarting regularly with liveness timeout under load? Increase `timeoutSeconds`. Make `/health` lightweight — no DB calls. Reserve heavy checks for `/ready`. Test probe responses under simulated production load.
