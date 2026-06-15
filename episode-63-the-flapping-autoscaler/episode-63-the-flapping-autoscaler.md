# Episode 63 — "The Flapping Autoscaler"
### *Inspector Ahmed and the HPA that can't make up its mind*

**Culprit:** HPA scaling up and down rapidly — scale-down too aggressive, no stabilization window
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `hpa` `autoscaling` `stabilization` `flapping` `scaling`

---

## OPENING — Crime scene

"The HPA was working — too well. It scaled up for a traffic spike. Then immediately scaled back down. Then the next request spike hit half-provisioned capacity. Then it scaled up again. The cluster was a revolving door of pods."

```bash
kubectl describe hpa api-hpa -n production
```

```
Events:
  Normal  SuccessfulRescale  10m  horizontal-pod-autoscaler
    New size: 8; reason: cpu resource utilization (percentage of request) above target
  Normal  SuccessfulRescale  7m   horizontal-pod-autoscaler
    New size: 3; reason: All metrics below target
  Normal  SuccessfulRescale  5m   horizontal-pod-autoscaler
    New size: 10; reason: cpu resource utilization above target
  Normal  SuccessfulRescale  3m   horizontal-pod-autoscaler
    New size: 3; reason: All metrics below target
```

Scaling up and down every few minutes. Each scale-down triggers a cold-start period where new requests hit under-provisioned pods — causing another spike — causing another scale-up.

> **📚 Teaching moment — HPA stabilization windows**
>
> The HPA has configurable stabilization windows (introduced in Kubernetes 1.18):
> - **scaleDown.stabilizationWindowSeconds**: how long to wait after last scale-up before scaling down (default: 300s = 5 minutes)
> - **scaleUp.stabilizationWindowSeconds**: how long to wait after metrics drop before scaling up (default: 0s = immediate)
>
> The default 5-minute scale-down window should prevent rapid flapping. If flapping is observed, check if the window was customised to be too short.

---

## ACT II — Adding a stabilization window

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
  namespace: production
spec:
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300   # wait 5 min before scaling down
      policies:
      - type: Percent
        value: 25                        # scale down max 25% per minute
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 30    # scale up quickly (30s)
      policies:
      - type: Percent
        value: 100                       # can double in 15s
        periodSeconds: 15
```

With this configuration:
- Scale-up is fast (can double replicas quickly when traffic spikes)
- Scale-down is conservative (waits 5 minutes, reduces max 25% per minute)

Flapping stops. The cluster maintains healthy capacity during and after traffic spikes.

---

## EPILOGUE

*"HPA flapping means scaling down too aggressively. Add a scale-down stabilization window of at least 300 seconds. Scale up fast, scale down slowly. Your users don't care about extra replicas — they care about being served."*

> **Inspector Ahmed's Rule #63:** HPA scaling up and down every few minutes? Set `scaleDown.stabilizationWindowSeconds: 300` and limit scale-down rate to 25% per minute. Scale up fast, scale down slow.
