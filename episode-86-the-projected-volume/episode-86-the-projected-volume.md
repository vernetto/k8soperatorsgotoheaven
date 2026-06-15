# Episode 86 — "The Projected Volume"
### *Inspector Ahmed and the ServiceAccount token that expired*

**Culprit:** Projected ServiceAccount token with a short expiry — pods fail to authenticate after expiry
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `serviceaccount` `token` `projected-volume` `authentication` `expiry`

---

## OPENING — Crime scene

"The application had been running for hours without issue. Then, exactly 1 hour after pod startup, it started getting 401 Unauthorized errors from the Kubernetes API. The token had expired."

```bash
kubectl logs api-7f9d4b-xk2p -n production | grep "401\|Unauthorized" | tail -5
```

```
[ERROR] Kubernetes API call failed: 401 Unauthorized
[ERROR] Token may have expired. Restarting token refresh...
[FATAL] Token refresh failed: token has expired
```

Token expired 1 hour after pod startup.

---

## ACT I — The token configuration

```bash
kubectl get pod api-7f9d4b-xk2p -n production -o yaml | grep -A 15 "volumes:"
```

```yaml
volumes:
- name: kube-api-access
  projected:
    sources:
    - serviceAccountToken:
        path: token
        expirationSeconds: 3600    ← 1 hour expiry
        audience: https://kubernetes.default.svc
```

`expirationSeconds: 3600`. The token expires in 1 hour. This is a **bound service account token** — introduced in Kubernetes 1.20, replacing the old long-lived tokens. These tokens are rotated automatically by the kubelet.

The problem: the application reads the token once at startup and caches it. When the token expires, the cache has a dead token.

> **📚 Teaching moment — Projected ServiceAccount tokens**
>
> Modern Kubernetes uses **projected volumes** for ServiceAccount tokens. These tokens:
> - Have a configurable expiry (default: 1 hour)
> - Are rotated automatically by the kubelet before expiry
> - Are audience-bound (can only be used with specific APIs)
> - Replace the old `kubernetes.io/service-account-token` Secret type
>
> The kubelet writes the new token to the projected volume file. Applications that read the token file directly always get the latest token. Applications that read it once and cache it will fail after expiry.
>
> **Fix in the application**: read the token from the file on every API call (or on every 401 response), not just at startup.

---

## ACT II — The application fix

```go
// Wrong: read once at startup
token, _ := os.ReadFile("/var/run/secrets/kubernetes.io/serviceaccount/token")
client.SetToken(string(token))

// Correct: read on each request (or on 401)
func getToken() string {
    token, _ := os.ReadFile("/var/run/secrets/kubernetes.io/serviceaccount/token")
    return string(token)
}

// Or: use the official Kubernetes client library — it handles token rotation automatically
config, _ := rest.InClusterConfig()  // reads and refreshes token automatically
```

Most official Kubernetes client libraries (Go, Python, Java) handle token rotation automatically when using `InClusterConfig()`. The application was using a custom HTTP client that read the token once.

---

## EPILOGUE

*"Projected ServiceAccount tokens expire by design. The kubelet rotates them — but only your code can pick up the rotation. Never cache the token. Read it from the file on every use, or use the official Kubernetes client library that handles this for you."*

> **Inspector Ahmed's Rule #86:** 401 errors from Kubernetes API exactly N seconds after pod startup? Projected token expired and the app cached it. Fix: read token from file on each call. Or better: use `rest.InClusterConfig()` from the official client library.
