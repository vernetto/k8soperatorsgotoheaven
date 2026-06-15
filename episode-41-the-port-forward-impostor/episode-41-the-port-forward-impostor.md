# Episode 41 — "The Port Forward Impostor"
### *Inspector Ahmed and the service that serves the wrong pod*

**Culprit:** Multiple deployments in same namespace with overlapping label selectors
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `labels` `selectors` `service` `routing` `debugging`

---

## OPENING — Crime scene

"The API was returning wrong data. Not errors — wrong data. Requests meant for v2 were getting v1 responses. Same service. Same namespace. Two deployments — and one service accidentally serving both."

```bash
kubectl get deployments -n production
```

```
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
api-v1      3/3     3            3           30d
api-v2      3/3     3            3           2d
```

Two deployments. Both running.

```bash
kubectl get svc api-service -n production -o yaml | grep -A 5 selector
```

```yaml
selector:
  app: api
```

The service selects on `app: api`. Ahmed checks the pod labels:

```bash
kubectl get pods -n production --show-labels | grep api
```

```
api-v1-7f9d4b-xk2p    app=api,version=v1
api-v1-7f9d4b-r8tn    app=api,version=v1
api-v2-9c2e1a-mn3k    app=api,version=v2
api-v2-9c2e1a-xr7w    app=api,version=v2
```

All four pods match `app: api`. The service load-balances across all four — 50% of requests go to v1, 50% to v2. Users get inconsistent responses depending on which pod serves them.

---

## ACT II — Fixing the selector

The service for v2 should only select v2 pods:

```bash
kubectl patch svc api-service -n production \
  --type=merge \
  -p '{"spec":{"selector":{"app":"api","version":"v2"}}}'
```

And the v1 deployment should be scaled down (it's being decommissioned):

```bash
kubectl scale deployment api-v1 --replicas=0 -n production
```

---

## EPILOGUE

*"A service that matches more pods than intended doesn't error — it silently load-balances. When two versions coexist in the same namespace, always include a version label in selectors. Otherwise the service serves both."*

> **Inspector Ahmed's Rule #41:** Wrong/inconsistent responses from a service? Check `kubectl get endpoints` — count the pods. If there are more than expected, the selector is too broad. Add a version label.
