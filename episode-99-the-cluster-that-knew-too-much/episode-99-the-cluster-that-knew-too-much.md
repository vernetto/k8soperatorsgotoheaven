# Episode 99 — "The Cluster That Knew Too Much"
### *Inspector Ahmed and the application that bypasses Kubernetes entirely*

**Culprit:** Application using raw Kubernetes API calls with hardcoded cluster URL — breaks when cluster is migrated
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `in-cluster-config` `api-server` `hardcoded` `portability` `client`

---

## OPENING — Crime scene

"The cluster was migrated to a new cloud region. All services came back up. Except one — an internal operator that made Kubernetes API calls. It was still trying to talk to the old cluster's API server, which no longer existed."

```bash
kubectl logs internal-operator-7f9d-xk2p -n operators
```

```
[ERROR] Failed to list deployments:
  Get "https://10.0.1.100:6443/apis/apps/v1/deployments":
  dial tcp 10.0.1.100:6443: connect: no route to host
```

`10.0.1.100:6443` — a hardcoded IP address. That was the old cluster's API server.

---

## ACT I — The configuration

```bash
kubectl exec internal-operator-7f9d-xk2p -n operators -- \
  cat /app/config/kube-config.yaml | grep server
```

```yaml
server: https://10.0.1.100:6443
```

The Kubernetes client config was hardcoded with the old cluster's IP. When the cluster was migrated, this IP was no longer valid.

> **📚 Teaching moment — In-cluster configuration**
>
> When a pod needs to call the Kubernetes API, there are two ways to configure the client:
>
> 1. **Hardcoded or file-based kubeconfig**: explicit cluster URL, credentials in a file. Breaks when the cluster is migrated or credentials rotate.
>
> 2. **In-cluster configuration**: the Kubernetes client library detects it's running inside a cluster and automatically uses:
>    - API server URL: `kubernetes.default.svc` (always valid inside the cluster)
>    - Token: from the projected ServiceAccount token at `/var/run/secrets/kubernetes.io/serviceaccount/token`
>    - CA: from `/var/run/secrets/kubernetes.io/serviceaccount/ca.crt`
>
>    In Go: `rest.InClusterConfig()`
>    In Python: `config.load_incluster_config()`
>    In JavaScript: the client library auto-detects when `KUBERNETES_SERVICE_HOST` env var is set
>
> Use in-cluster configuration for any pod that calls the Kubernetes API. It is portable, automatically updated, and never hardcodes credentials.

---

## ACT II — The fix

```go
// Wrong: hardcoded config
config, err := clientcmd.BuildConfigFromFlags(
  "https://10.0.1.100:6443",
  "/app/config/kube-config.yaml",
)

// Correct: in-cluster config
config, err := rest.InClusterConfig()
if err != nil {
  // Fallback to kubeconfig for local development
  config, err = clientcmd.BuildConfigFromFlags("", os.Getenv("KUBECONFIG"))
}
```

After redeploying with in-cluster config, the operator connects to `https://kubernetes.default.svc` — which always resolves to the current cluster's API server regardless of where the cluster lives.

---

## EPILOGUE

*"Never hardcode a Kubernetes API server URL in a pod. Use in-cluster configuration — `rest.InClusterConfig()` or equivalent. It uses `kubernetes.default.svc` which always works inside the cluster. Hardcoded IPs break on cluster migration, IP changes, or any infrastructure update."*

> **Inspector Ahmed's Rule #99:** Pod calling Kubernetes API with a hardcoded URL? Switch to `InClusterConfig()`. It automatically uses `kubernetes.default.svc` and the projected ServiceAccount token. Works in any cluster, any region, any cloud.
