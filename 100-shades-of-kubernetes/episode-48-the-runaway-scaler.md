# Episode 48 — "The Runaway Scaler"
### *Inspector Ahmed and the HPA that scales to zero*

**Culprit:** Custom metrics HPA receives 0 values from dead metrics adapter — scales deployment to minimum
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `hpa` `custom-metrics` `prometheus-adapter` `autoscaling`

---

## OPENING — Crime scene

"Traffic was normal. The application was handling thousands of requests per minute. Then suddenly — zero replicas. The HPA had scaled the deployment to its minimum. With thousands of requests in flight."

```bash
kubectl get hpa api-hpa -n production
```

```
NAME      REFERENCE            TARGETS   MINPODS   MAXPODS   REPLICAS
api-hpa   Deployment/api       0/100     1         20        1
```

Target: `0/100`. The HPA thinks the current metric value is 0 — below the threshold — so it's scaling down aggressively.

---

## ACT I — The dead metrics adapter

The HPA is based on a custom metric: `http_requests_per_second`, provided by Prometheus Adapter.

```bash
kubectl get pods -n monitoring | grep prometheus-adapter
```

```
NAME                           READY   STATUS             RESTARTS   AGE
prometheus-adapter-7f9d-xk2p   0/1     CrashLoopBackOff   8          1h
```

The Prometheus Adapter is crashing. When the HPA queries for the metric and gets an error (or no data), it treats the metric as 0. With a threshold of 100 and a current value of 0, the HPA scales down to minimum replicas.

> **📚 Teaching moment — HPA behaviour with missing metrics**
>
> When an HPA can't retrieve metrics, it doesn't pause — it uses 0 as the metric value. This means:
> - For scale-up triggers (scale up when metric > threshold): metric=0 means no scaling up. Traffic piles up but HPA doesn't know.
> - For scale-down triggers: metric=0 means scale to minimum. This is the dangerous case.
>
> Mitigation: set `minReplicas` high enough that scaling to minimum isn't catastrophic. Or use Keda with a `fallback` configuration that prevents scale-to-zero when metrics are unavailable.

---

## ACT II — Fix the adapter

```bash
kubectl logs prometheus-adapter-7f9d-xk2p -n monitoring --previous
```

```
Error: failed to connect to Prometheus at http://prometheus:9090:
  dial tcp: lookup prometheus on 10.96.0.10:53: no such host
```

The Prometheus service was renamed. Adapter can't find it.

```bash
kubectl get svc -n monitoring | grep prometheus
```

```
prometheus-server   ClusterIP   10.96.88.44   9090/TCP   30d
```

Service is now `prometheus-server`, not `prometheus`. Ahmed updates the adapter config:

```bash
kubectl edit configmap prometheus-adapter-config -n monitoring
# Change baseURL to http://prometheus-server:9090
kubectl rollout restart deployment/prometheus-adapter -n monitoring
```

Scale the deployment back up manually while the adapter recovers:

```bash
kubectl scale deployment api --replicas=10 -n production
```

---

## EPILOGUE

*"Custom metrics HPAs are powerful — and fragile. If the metrics adapter dies, the HPA scales to zero. Always set a reasonable minReplicas. Consider KEDA's fallback. Monitor your metrics adapters with the same vigilance as your applications."*

> **Inspector Ahmed's Rule #48:** HPA scaling to minimum despite traffic? Custom metrics returning 0? Check the metrics adapter pod. Broken adapter = 0 metric = aggressive scale-down. Fix adapter, then manually restore replicas.
