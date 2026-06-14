# Episode 80 — "The ReadinessGate"
### *Inspector Ahmed and the pod that is Ready but not Ready*

**Culprit:** Pod has a ReadinessGate condition that is never set — pod never becomes Ready for traffic
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `readinessgate` `conditions` `custom-conditions` `service-mesh` `traffic`

---

## OPENING — Crime scene

"The pod passed its readiness probe. All containers were running. But the pod never appeared in the service endpoints. The status showed `Ready: False` — despite all containers being healthy. A condition was missing."

```bash
kubectl get pod api-7f9d4b-xk2p -n production
```

```
NAME                   READY   STATUS    RESTARTS   AGE
api-7f9d4b-xk2p        0/1     Running   0          5m
```

`0/1` — not ready. But:

```bash
kubectl describe pod api-7f9d4b-xk2p -n production | grep -A 5 "Readiness"
```

```
Readiness:  http-get http://:8080/health delay=5s timeout=3s period=10s #success=1 #failure=3
  Status:   True
```

Readiness probe: True. But pod is still `0/1`.

---

## ACT I — The ReadinessGate

```bash
kubectl get pod api-7f9d4b-xk2p -n production -o yaml | grep -A 10 "readinessGates\|conditions"
```

```yaml
readinessGates:
- conditionType: "feature-gate/traffic-allowed"

status:
  conditions:
  - type: Initialized
    status: "True"
  - type: Ready
    status: "False"
  - type: ContainersReady
    status: "True"
  - type: PodScheduled
    status: "True"
  - type: feature-gate/traffic-allowed
    status: "False"     ← this is not set to True
```

A `ReadinessGate` requires a custom condition `feature-gate/traffic-allowed` to be `True` before the pod is considered Ready. This condition is `False` — likely because the external controller that manages it (a canary deployment system or service mesh controller) is not running.

> **📚 Teaching moment — Pod ReadinessGates**
>
> ReadinessGates extend pod readiness beyond container health probes. A pod with ReadinessGates is only Ready (and only receives traffic) when:
> 1. All containers pass their readiness probes
> 2. ALL ReadinessGate conditions are `True`
>
> These gates are set by external controllers (service mesh, canary operators, custom controllers). If the controller is down or misconfigured, the conditions are never set, and pods stay in `0/1` forever — even though all containers are healthy.
>
> Common users: Istio's traffic management, progressive delivery tools (Argo Rollouts, Flagger).

---

## ACT II — Diagnosing and fixing

```bash
kubectl get pods -n traffic-controller
```

```
NAME                          READY   STATUS    RESTARTS   AGE
traffic-gate-controller-xk2p  0/1     Pending   0          3h
```

The traffic gate controller is Pending — it was never scheduled because its node selector points to a node type that doesn't exist in this cluster. Fix the controller:

```bash
kubectl patch deployment traffic-gate-controller -n traffic-controller \
  --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/nodeSelector"}]'
```

Once the controller starts, it sets `feature-gate/traffic-allowed: True` on the pods and they become Ready.

As an emergency workaround — if the ReadinessGate is no longer needed:

```bash
kubectl patch pod api-7f9d4b-xk2p -n production \
  --type=json \
  -p='[{"op":"replace","path":"/status/conditions/4/status","value":"True"}]' \
  --subresource=status
```

---

## EPILOGUE

*"ReadinessGates make pod readiness depend on external controllers. If that controller is down, all pods with the gate stay unready. Check pod conditions for custom gate types. Find the controller that should be setting them."*

> **Inspector Ahmed's Rule #80:** Pod containers all healthy but pod shows 0/1? Check for ReadinessGates. `kubectl get pod -o yaml | grep readinessGates`. Find the controller that sets those conditions. Fix the controller.
