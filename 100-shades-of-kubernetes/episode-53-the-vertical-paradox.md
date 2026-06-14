# Episode 53 — "The Vertical Paradox"
### *Inspector Ahmed and the VPA that fights the HPA*

**Culprit:** VPA and HPA both managing the same deployment — they conflict and cause thrashing
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `vpa` `hpa` `autoscaling` `conflict` `resources`

---

## OPENING — Crime scene

"The deployment was unstable. Pods were being restarted constantly. Resource requests kept changing. The replica count kept fluctuating. Two autoscalers had been configured for the same workload — and they were fighting each other."

```bash
kubectl get hpa,vpa -n production
```

```
NAME                               REFERENCE            TARGETS   MINPODS   MAXPODS   REPLICAS
horizontalpodautoscaler/api-hpa    Deployment/api       65%/70%   2         20        8

NAME                            MODE   CPU   MEM          PROVIDED   AGE
verticalpodautoscaler/api-vpa   Auto   95m   128Mi        True       5d
```

Both an HPA (scaling replicas) and a VPA (scaling resource requests) on the same deployment.

> **📚 Teaching moment — VPA + HPA conflict**
>
> **HPA** scales the number of replicas based on CPU/memory utilisation.
> **VPA** adjusts the resource requests/limits on pods based on observed usage.
>
> In `Auto` mode, VPA evicts pods and recreates them with updated resource requests. This changes the per-pod CPU request — which changes utilisation — which triggers HPA to change replica count — which changes total load per pod — which triggers VPA again. Infinite loop.
>
> **Safe combinations:**
> - HPA on CPU/memory + VPA in `Off` mode (VPA gives recommendations only)
> - HPA on custom metrics (not CPU/memory) + VPA in `Auto` mode
> - VPA alone (no HPA)
>
> Never run VPA in `Auto` mode with HPA scaling on the same CPU/memory metrics.

---

## ACT II — The fix

Set VPA to `Off` mode (recommendations only, no automatic updates):

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: api-vpa
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  updatePolicy:
    updateMode: "Off"    # Recommendations only
```

```bash
kubectl apply -f api-vpa.yaml
```

Now VPA provides recommendations that the team can apply manually, while HPA handles automatic scaling. The thrashing stops.

```bash
kubectl describe vpa api-vpa -n production | grep -A 10 "Recommendation"
```

```
    Recommendation:
      Container Recommendations:
        Container Name: api
        Lower Bound:    cpu: 80m  memory: 100Mi
        Target:         cpu: 95m  memory: 128Mi
        Upper Bound:    cpu: 200m memory: 250Mi
```

The team uses these recommendations to right-size the resource requests in the deployment spec.

---

## EPILOGUE

*"VPA and HPA can coexist — but not when both are scaling based on CPU and memory. If you use HPA for scaling, use VPA in Off mode for recommendations only. Let one system make the decisions."*

> **Inspector Ahmed's Rule #53:** Pods restarting frequently with changing resource requests? Check for VPA in Auto mode alongside HPA. Set VPA to `Off` mode and use its recommendations manually.
