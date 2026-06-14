# Episode 15 — "The Thundering Herd"
### *Inspector Ahmed and the HPA that does nothing*

**Culprit:** HorizontalPodAutoscaler not scaling — metrics-server not installed
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `hpa` `autoscaling` `metrics-server` `cpu` `scaling`

---

## OPENING — Crime scene

"CPU was at 95%. The HPA was configured to scale at 70%. The team had been watching the graph climb for twenty minutes, waiting for new pods to appear. They never did."

```bash
kubectl get hpa -n production
```

```
NAME         REFERENCE              TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
api-hpa      Deployment/api         <unknown>/70%   2         10        2          30m
```

`<unknown>`. The HPA doesn't know the current CPU usage. It can't scale based on metrics it can't read.

---

## ACT I — The missing instrument

```bash
kubectl describe hpa api-hpa -n production
```

```
Events:
  Warning  FailedGetScale  28m  horizontal-pod-autoscaler
    failed to get cpu utilization: unable to get metrics for resource cpu:
    unable to fetch metrics from resource metrics API:
    the server is currently unable to handle the request (get pods.metrics.k8s.io)
```

The metrics API is unreachable. The HPA uses `metrics.k8s.io` to get CPU/memory data — provided by the **metrics-server**.

```bash
kubectl get deployment metrics-server -n kube-system
```

```
Error from server (NotFound): deployments.apps "metrics-server" not found
```

No metrics-server. No metrics. No autoscaling.

> **📚 Teaching moment — HPA and metrics-server**
>
> The HPA queries the Kubernetes Metrics API (`metrics.k8s.io`) for resource usage. This API is *not built into Kubernetes* — it's provided by the **metrics-server** component, which must be separately installed.
>
> Without metrics-server, `kubectl top pods`, `kubectl top nodes`, and HPAs based on CPU/memory all fail.

---

## ACT II — Installing metrics-server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Wait 60 seconds for it to collect initial metrics:

```bash
kubectl get hpa -n production
```

```
NAME         REFERENCE              TARGETS    MINPODS   MAXPODS   REPLICAS   AGE
api-hpa      Deployment/api         95%/70%    2         10        2          35m
```

The HPA sees 95% CPU — above the 70% threshold. Scaling begins immediately:

```bash
kubectl get pods -n production
```

```
NAME                  READY   STATUS    RESTARTS   AGE
api-7f9d4b-xk2p       1/1     Running   0          35m
api-7f9d4b-r8tn       1/1     Running   0          35m
api-7f9d4b-9lmw       1/1     Running   0          12s
api-7f9d4b-mn2x       1/1     Running   0          12s
```

Two new pods. CPU drops below threshold.

---

## EPILOGUE

*"An HPA showing `<unknown>` is not broken — it's blind. Give it eyes. Install metrics-server. Then it will do exactly what it was configured to do."*

> **Inspector Ahmed's Rule #15:** `<unknown>` in HPA targets = metrics-server missing. Install it. One command. Autoscaling works immediately.
