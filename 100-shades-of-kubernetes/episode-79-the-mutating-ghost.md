# Episode 79 — "The Mutating Ghost"
### *Inspector Ahmed and the pod that spawns with unexpected configuration*

**Culprit:** MutatingAdmissionWebhook silently modifying pod specs — added annotation prevents scheduling
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `mutatingwebhook` `admission` `pod-spec` `debugging`

---

## OPENING — Crime scene

"The deployment YAML was correct. The team had checked it three times. But every pod that was created had extra annotations — annotations that triggered a policy enforcement tool — and those annotations caused the pods to be rejected by another admission controller. The ghost was in the admission chain."

```bash
kubectl get pod api-7f9d4b-xk2p -n production -o yaml | grep annotations -A 10
```

```yaml
annotations:
  app.kubernetes.io/name: api
  policy.company.com/scan-required: "true"      ← not in original spec
  policy.company.com/scan-status: "pending"     ← not in original spec
```

Two annotations appeared that were never in the deployment spec. They come from a MutatingWebhook.

```bash
kubectl get mutatingwebhookconfiguration
```

```
NAME                        WEBHOOKS   AGE
policy-injector             1          60d
istio-sidecar-injector      1          60d
```

The `policy-injector` webhook adds `scan-required: "true"` to every pod. A separate ValidatingWebhook then checks: if `scan-required: true` but `scan-status != completed`, reject the pod. The scan service is down. Every pod is rejected.

> **📚 Teaching moment — Debugging admission webhook chains**
>
> When a pod arrives at the API server, it passes through multiple admission webhooks in sequence. Mutating webhooks run first (they can modify the request), then Validating webhooks run on the (possibly mutated) request.
>
> To debug: use `kubectl apply --dry-run=server` to see what the API server would actually create — including all webhook mutations — without actually creating the resource.
>
> ```bash
> kubectl apply -f deployment.yaml --dry-run=server -o yaml
> ```
> This shows the final mutated spec.

---

## ACT II — Fixing the broken scan service

```bash
kubectl get pods -n policy-system
```

```
NAME                      READY   STATUS             RESTARTS   AGE
scan-service-7f9d-xk2p    0/1     CrashLoopBackOff   15         2h
```

The scan service is down. While it's fixed, the team patches the MutatingWebhook to add a namespace selector exclusion for the production namespace:

```bash
kubectl patch mutatingwebhookconfiguration policy-injector \
  --type=json \
  -p='[{"op":"add","path":"/webhooks/0/namespaceSelector","value":{"matchExpressions":[{"key":"bypass-policy","operator":"DoesNotExist"}]}}]'

kubectl label namespace production bypass-policy=true
```

Pods in `production` now bypass the injector while the scan service is repaired.

---

## EPILOGUE

*"When a pod arrives with unexpected fields, a MutatingWebhook added them. Use `kubectl apply --dry-run=server` to see the fully mutated spec. Trace the admission chain to find which webhook added what. Broken webhook chains can bring entire namespaces down."*

> **Inspector Ahmed's Rule #79:** Pods created with unexpected annotations or fields? `kubectl get mutatingwebhookconfiguration` — find the injector. Use `--dry-run=server` to see mutations. Fix the webhook or add a namespace exclusion selector.
