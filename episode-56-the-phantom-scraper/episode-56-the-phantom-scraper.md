# Episode 56 — "The Phantom Scraper"
### *Inspector Ahmed and the metrics that never arrive*

**Culprit:** Prometheus scraping wrong port — metrics endpoint exists but isn't being collected
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `prometheus` `monitoring` `annotations` `scraping` `metrics`

---

## OPENING — Crime scene

"The dashboard showed no metrics for the new service. Not zero metrics — no metrics at all. The service had been instrumented perfectly. The /metrics endpoint returned data. Prometheus just wasn't looking there."

```bash
curl http://api-pod-ip:8080/metrics | head -5
```

```
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",status="200"} 4821
http_requests_total{method="POST",status="201"} 293
```

The metrics endpoint works. But Prometheus shows no data for this service.

---

## ACT I — The scrape configuration

Prometheus (via prometheus-operator or default config) discovers pods to scrape using annotations:

```bash
kubectl get pod api-7f9d4b-xk2p -n production -o yaml | grep -A 10 "annotations:"
```

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9090"
  prometheus.io/path: "/metrics"
```

`prometheus.io/port: "9090"`. But the application serves metrics on port 8080. Prometheus is dutifully scraping port 9090 — which returns nothing because nothing listens there.

> **📚 Teaching moment — Prometheus pod scrape annotations**
>
> When using the standard `prometheus.io/*` annotations (used by many default Prometheus configs), the following are key:
> - `prometheus.io/scrape: "true"` — opt this pod in for scraping
> - `prometheus.io/port: "<port>"` — which container port to scrape (default: first container port)
> - `prometheus.io/path: "<path>"` — metrics endpoint path (default: `/metrics`)
> - `prometheus.io/scheme: "https"` — if metrics are served over HTTPS
>
> If the port is wrong, Prometheus connects to the wrong port, gets a connection refused or empty response, and records no metrics.

---

## ACT II — The fix

```bash
kubectl patch pod api-7f9d4b-xk2p -n production \
  --type=merge \
  -p '{"metadata":{"annotations":{"prometheus.io/port":"8080"}}}'
```

Since annotations are usually set on the Deployment template:

```bash
kubectl patch deployment api -n production \
  --type=merge \
  -p '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/port":"8080"}}}}}'
```

Within one Prometheus scrape interval (default 15s), metrics start arriving.

If using prometheus-operator with ServiceMonitor:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: api-monitor
  namespace: production
spec:
  selector:
    matchLabels:
      app: api
  endpoints:
  - port: metrics        # must match a named port in the Service
    path: /metrics
    interval: 15s
```

---

## EPILOGUE

*"No metrics in Prometheus doesn't mean the app isn't instrumented — it means Prometheus isn't looking in the right place. Check annotations for the correct port. A typo in prometheus.io/port means complete monitoring blindness."*

> **Inspector Ahmed's Rule #56:** No metrics in Prometheus for a pod that has a /metrics endpoint? Check `prometheus.io/port` annotation. Verify it matches the actual port. Check Prometheus targets page for scrape errors.
