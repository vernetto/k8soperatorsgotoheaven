# Episode 77 — "The Sidecar Dependency"
### *Inspector Ahmed and the app that dies when its proxy starts first*

**Culprit:** Init container ordering issue — main container starts before sidecar is ready
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `sidecar` `init-containers` `startup-order` `dependencies` `istio`

---

## OPENING — Crime scene

"The application crashed on every pod restart — but only for the first 10 seconds. After that, it ran fine indefinitely. The crash always happened at startup when the app tried to reach an external service through the Envoy sidecar before Envoy was ready to proxy."

```bash
kubectl logs api-7f9d4b-xk2p -n production -c api --previous
```

```
[INFO]  Starting application...
[INFO]  Connecting to config-service for startup configuration...
[ERROR] Failed to reach config-service: connection refused
[FATAL] Cannot load startup config. Exiting.
```

Connection refused during startup. But when Ahmed checks manually:

```bash
kubectl exec api-7f9d4b-xk2p -n production -c api -- \
  curl http://config-service:8080/config
```

```
{"config": "..."}
```

Works fine. The service is reachable — just not during the 5-second startup window.

---

## ACT I — The sidecar race

```bash
kubectl get pod api-7f9d4b-xk2p -n production -o jsonpath='{.spec.containers[*].name}'
```

```
api istio-proxy
```

Two containers. In Kubernetes, all containers in a pod start simultaneously. The `api` container starts, immediately tries to connect through the Envoy proxy — but Envoy hasn't finished initialising yet. Connection refused. App crashes.

> **📚 Teaching moment — Sidecar startup ordering**
>
> Kubernetes starts all containers in a pod at the same time. There is no guaranteed ordering between containers. If your app depends on a sidecar being ready (Envoy proxy, Vault agent, log shipper), you must implement the waiting yourself.
>
> Solutions:
> 1. **Retry logic in the app**: the application retries connections on startup with exponential backoff — the most robust solution
> 2. **postStart lifecycle hook**: delay app startup until sidecar is ready
> 3. **Kubernetes 1.29+ native sidecar**: mark sidecar containers with `restartPolicy: Always` in initContainers — they start before the main container
> 4. **Wrapper script**: poll for sidecar readiness before launching app

---

## ACT II — The fix

**Option A — Add retry logic to the application** (correct long-term fix):

```javascript
async function connectWithRetry(url, maxAttempts = 10) {
  for (let i = 0; i < maxAttempts; i++) {
    try {
      return await connect(url);
    } catch (err) {
      await sleep(Math.min(1000 * Math.pow(2, i), 10000));
    }
  }
  throw new Error('Connection failed after retries');
}
```

**Option B — Kubernetes 1.29+ native sidecar** (if available):

```yaml
initContainers:
- name: istio-proxy
  image: istio/proxyv2:latest
  restartPolicy: Always    # marks this as a sidecar — runs through pod lifetime
  # ... normal sidecar config
containers:
- name: api
  # ... app starts after all initContainers (including sidecars) are ready
```

The team implements Option A — it's more portable and defensive.

---

## EPILOGUE

*"Never assume a sidecar is ready when your main container starts. They start simultaneously. Build retry logic into your application. Or use Kubernetes 1.29+ native sidecar containers which provide guaranteed startup ordering."*

> **Inspector Ahmed's Rule #77:** App crashes only in the first seconds after startup, then works fine? Sidecar not ready when app started. Add retry logic to the app's startup code. Or use native sidecar containers (k8s 1.29+).
