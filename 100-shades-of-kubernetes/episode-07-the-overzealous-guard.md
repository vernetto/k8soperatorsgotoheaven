# Episode 7 — "The Overzealous Guard"
### *Inspector Ahmed and the probe that kills what it's supposed to protect*

**Culprit:** Liveness probe too aggressive — killing healthy pods during startup
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `liveness-probe` `readiness-probe` `probes` `startup`

---

## OPENING — Crime scene

"The new version had been deployed. The pods were starting. And then, just as they were about to become ready — they died. Over and over. The developer swore the app was working fine locally. Ahmed believed him. The probe did not."

```bash
kubectl get pods -n production
```

```
NAME                      READY   STATUS    RESTARTS   AGE
app-v2-7f9d4b-xk2p        0/1     Running   6          9m
app-v2-7f9d4b-r8tn        0/1     Running   5          9m
```

Running — but never Ready. Restarts climbing. The pods never reach `1/1`.

---

## ACT I — The timeline

```bash
kubectl describe pod app-v2-7f9d4b-xk2p -n production
```

```
Events:
  Type     Reason     Age                From     Message
  ----     ------     ----               ----     -------
  Normal   Pulled     9m                 kubelet  Successfully pulled image
  Normal   Created    9m                 kubelet  Created container app
  Normal   Started    9m                 kubelet  Started container app
  Warning  Unhealthy  8m (x6 over 9m)   kubelet  Liveness probe failed:
                                                   HTTP probe failed with
                                                   statuscode: 503
  Warning  Killing    8m (x6 over 9m)   kubelet  Container app failed
                                                   liveness probe, will be restarted
```

The liveness probe is failing — and killing the container — before the application is ready to respond. Every time the pod starts, the probe fires too early, gets a 503 (the app is still initialising), and kills the pod.

> **📚 Teaching moment — Liveness vs Readiness vs Startup probes**
>
> Kubernetes has three probes:
> - **Liveness**: is the app alive? If this fails, the container is *killed and restarted*.
> - **Readiness**: is the app ready to receive traffic? If this fails, the pod is removed from Service endpoints — but not killed.
> - **Startup**: is the app done starting? While this probe is active, liveness and readiness are disabled. If startup fails after its `failureThreshold`, the container is killed.
>
> The startup probe was introduced precisely because of this scenario: apps with slow startup times were being killed by liveness probes before they could initialise.

---

## ACT II — The probe configuration

```bash
kubectl get deployment app-v2 -n production -o yaml | grep -A 20 "livenessProbe"
```

```yaml
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 3
```

`initialDelaySeconds: 5`. The probe waits 5 seconds after container start, then fires every 5 seconds. If it fails 3 times (15 seconds), the container is killed.

Ahmed checks how long the app actually takes to start:

```bash
kubectl logs app-v2-7f9d4b-xk2p -n production
```

```
[INFO]  Loading configuration...
[INFO]  Connecting to database...
[INFO]  Running database migrations... (this may take a moment)
[INFO]  Migration complete: 847 migrations applied
[INFO]  Warming up cache...
[INFO]  Server ready on :8080
```

The app runs migrations on startup. With 847 migrations — some with large data transforms — this takes roughly 90 seconds. The liveness probe kills it at second 20.

---

## ACT III — The fix

Ahmed has three tools available:

**Option A — Increase `initialDelaySeconds`** (crude but works for stable startup times):

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 120
  periodSeconds: 10
  failureThreshold: 3
```

**Option B — Add a `startupProbe`** (recommended — disables liveness until startup succeeds):

```yaml
startupProbe:
  httpGet:
    path: /health
    port: 8080
  failureThreshold: 30    # allow up to 30 * 10s = 5 minutes for startup
  periodSeconds: 10

livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 0  # startup probe handles the delay now
  periodSeconds: 10
  failureThreshold: 3
```

**Option C — Fix the root cause:** don't run database migrations at startup. Use an init container or a separate migration job instead. This keeps startup fast and predictable.

The team implements Option B immediately and opens a ticket for Option C.

```bash
kubectl apply -f deployment-with-startup-probe.yaml
kubectl rollout status deployment/app-v2 -n production
```

```
Waiting for deployment "app-v2" rollout to finish: 1 out of 2 new replicas...
deployment "app-v2" successfully rolled out
```

---

## EPILOGUE

*"A liveness probe that kills healthy pods isn't a safety net — it's a trap. The startup probe exists for exactly this reason. Use it whenever your app takes more than 20 seconds to initialise."*

> **📚 Episode takeaways**
>
> | Probe type | What happens on failure |
> |---|---|
> | Liveness | Container is killed and restarted |
> | Readiness | Pod removed from Service endpoints — not killed |
> | Startup | Container killed if startup doesn't complete in time |
>
> **Inspector Ahmed's Rule #7:** If a new version keeps restarting without crashing, suspect the liveness probe. Check `initialDelaySeconds` against the real startup time. Add a `startupProbe` for apps with slow initialisation.
