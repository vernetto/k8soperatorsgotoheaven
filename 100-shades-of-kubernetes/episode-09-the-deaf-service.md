# Episode 9 — "The Deaf Service"
### *Inspector Ahmed and the service that never forwards traffic*

**Culprit:** Service selector doesn't match pod labels
**Difficulty:** ⭐ Beginner
**Tags:** `service` `labels` `selectors` `endpoints` `networking`

---

## OPENING — Crime scene

"The pod was running. The service existed. The port was correct. And yet, every request to the service returned a timeout or a connection refused. Ahmed had seen this exact crime committed by developers in a hurry a hundred times."

```bash
kubectl get pods,svc -n production
```

```
NAME                           READY   STATUS    RESTARTS   AGE
pod/api-deployment-7f9d-xk2p   1/1     Running   0          10m

NAME                   TYPE        CLUSTER-IP      PORT(S)    AGE
service/api-service    ClusterIP   10.96.55.201    8080/TCP   10m
```

Pod running. Service present. Ahmed goes straight to endpoints.

```bash
kubectl get endpoints api-service -n production
```

```
NAME          ENDPOINTS   AGE
api-service   <none>      10m
```

`<none>`. No endpoints. The service has no idea where to send traffic.

---

## ACT I — Label forensics

A Service finds its pods through **label selectors**. If the selector doesn't match any pod labels, the endpoints list is empty and traffic goes nowhere.

```bash
kubectl describe svc api-service -n production | grep Selector
```

```
Selector: app=api,tier=backend
```

The service is looking for pods with *both* labels: `app=api` AND `tier=backend`.

```bash
kubectl get pod api-deployment-7f9d-xk2p -n production --show-labels
```

```
NAME                          READY   STATUS    LABELS
api-deployment-7f9d-xk2p      1/1     Running   app=api,env=production
```

The pod has `app=api` but not `tier=backend`. One label is missing. The selector fails, the service has no endpoints, all traffic drops.

> **📚 Teaching moment — How Service selectors work**
>
> A Service selector is a logical AND. All labels in the selector must be present on the pod. If the service has `app=api,tier=backend` and the pod has only `app=api`, the pod is invisible to the service.
>
> This is one of the most common Kubernetes mistakes: mismatched labels between Service and Deployment template, often caused by a typo or a copy-paste error.

---

## ACT II — Finding the discrepancy

```bash
kubectl get deployment api-deployment -n production -o yaml | grep -A 10 "template:" | grep -A 5 "labels:"
```

```yaml
      labels:
        app: api
        env: production
```

The service was written expecting `tier: backend` which the developer forgot to add to the pod template.

---

## ACT III — The fix

**Option A — Add the missing label to the deployment:**

```bash
kubectl patch deployment api-deployment -n production \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/metadata/labels/tier","value":"backend"}]'
```

**Option B — Remove the extra label requirement from the service:**

```bash
kubectl patch svc api-service -n production \
  --type='json' \
  -p='[{"op":"remove","path":"/spec/selector/tier"}]'
```

Ahmed goes with Option A — the service selector was intentional. The deployment was missing the label.

```bash
kubectl get endpoints api-service -n production
```

```
NAME          ENDPOINTS            AGE
api-service   10.244.2.14:8080     10m
```

---

## EPILOGUE

*"Always check endpoints before debugging anything else. An empty endpoints list means the service has no pods to talk to — and that's a label problem, not a networking problem."*

> **📚 Episode takeaways**
>
> | Command | What it's for |
> |---|---|
> | `kubectl get endpoints <svc>` | First check — are there any endpoints? |
> | `kubectl describe svc` → Selector | What labels does the service require? |
> | `kubectl get pod --show-labels` | What labels does the pod actually have? |
>
> **Inspector Ahmed's Rule #9:** Before debugging any networking issue, run `kubectl get endpoints`. Empty endpoints = label mismatch. Full stop.
