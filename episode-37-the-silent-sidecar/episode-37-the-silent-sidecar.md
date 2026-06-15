# Episode 37 — "The Silent Sidecar"
### *Inspector Ahmed and the service mesh that breaks mutual TLS*

**Culprit:** Istio sidecar injected on one side only — mTLS handshake fails
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `istio` `service-mesh` `mtls` `sidecar` `envoy`

---

## OPENING — Crime scene

"A new service was deployed. It could reach the database, external APIs, and everything outside the mesh. But it couldn't reach *any* other service inside the cluster. Every request returned `connection reset by peer`."

```bash
kubectl exec new-service-7f9d4b-xk2p -n production -- \
  curl http://backend-api:8080/health
```

```
curl: (56) Recv failure: Connection reset by peer
```

Not refused. Not timed out. *Reset*. That's a TLS handshake failure — the connection was established and then torn down mid-handshake.

---

## ACT I — The mesh asymmetry

```bash
kubectl get pod new-service-7f9d4b-xk2p -n production \
  -o jsonpath='{.spec.containers[*].name}'
```

```
new-service
```

One container. No sidecar.

```bash
kubectl get pod backend-api-6d8f9c-r8tn -n production \
  -o jsonpath='{.spec.containers[*].name}'
```

```
backend-api istio-proxy
```

Two containers — `istio-proxy` is the Envoy sidecar. The backend has a sidecar; the new service doesn't.

With Istio's `STRICT` mTLS mode, the backend pod's Envoy proxy requires all incoming traffic to present a valid mTLS certificate. The new service has no sidecar and can't present one. The proxy rejects the connection.

> **📚 Teaching moment — Istio sidecar injection**
>
> Istio injects the Envoy proxy sidecar automatically when a pod is created in a namespace labeled `istio-injection: enabled`. If you deploy a pod *before* the namespace is labeled, or into a namespace without the label, the pod has no sidecar.
>
> In STRICT mTLS mode, sidecar-less pods cannot communicate with sidecar-bearing pods, because they can't participate in the mutual TLS handshake.

---

## ACT II — The fix

```bash
# Check namespace label
kubectl get namespace production --show-labels | grep istio-injection
```

```
# Not present
```

```bash
# Enable sidecar injection for the namespace
kubectl label namespace production istio-injection=enabled
```

Then restart the new service so the sidecar is injected:

```bash
kubectl rollout restart deployment/new-service -n production
kubectl get pod new-service-8a2b1c-xk2p -n production \
  -o jsonpath='{.spec.containers[*].name}'
```

```
new-service istio-proxy
```

```bash
kubectl exec new-service-8a2b1c-xk2p -n production -- \
  curl http://backend-api:8080/health
```

```
{"status":"ok"}
```

---

## EPILOGUE

*"In a service mesh, asymmetry kills. If one pod has a sidecar and the other doesn't, mTLS fails silently. Always label namespaces for sidecar injection before deploying into them. And always restart existing pods after labelling."*

> **Inspector Ahmed's Rule #37:** `connection reset by peer` inside an Istio mesh = sidecar mismatch. Check both pods' container lists. Enable `istio-injection=enabled` on the namespace and restart the pod.
