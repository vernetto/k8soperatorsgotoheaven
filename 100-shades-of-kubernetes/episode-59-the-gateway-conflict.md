# Episode 59 — "The Gateway Conflict"
### *Inspector Ahmed and two routing systems at war*

**Culprit:** Both Ingress and Gateway API resources defined for the same routes — traffic goes nowhere predictably
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `gateway-api` `ingress` `routing` `conflict` `networking`

---

## OPENING — Crime scene

"Some traffic reached the application. Some didn't. The same URL worked from some clients and not others. The cluster was running both an old Ingress and a new Gateway API HTTPRoute for the same hostname — and they were fighting."

```bash
kubectl get ingress,httproute -n production
```

```
NAME                               CLASS   HOSTS               ADDRESS
ingress.networking.k8s.io/api-ig   nginx   api.example.com     203.0.113.42

NAME                                          HOSTNAMES
httproute.gateway.networking.k8s.io/api-rt   ["api.example.com"]
```

Both an Ingress (nginx class) and an HTTPRoute (Gateway API) claim `api.example.com`. Depending on which load balancer receives the request, it might hit the nginx ingress or the gateway controller.

> **📚 Teaching moment — Ingress vs Gateway API**
>
> Kubernetes is migrating from the `Ingress` API to the **Gateway API** (`HTTPRoute`, `Gateway`, `GRPCRoute`, etc.). Gateway API is more expressive and supports traffic splitting, header-based routing, and multi-protocol support.
>
> During migration, both can coexist if they use different addresses or controllers. But if both claim the same hostname and the DNS points to both (or to an ambiguous LB), requests are routed unpredictably.
>
> Rule: migrate completely, don't half-migrate. One system should own each hostname.

---

## ACT II — Choosing one

The team decides to fully migrate to Gateway API. Ahmed deletes the old Ingress:

```bash
kubectl delete ingress api-ig -n production
```

The HTTPRoute and Gateway now exclusively own `api.example.com`. Traffic becomes consistent.

If the migration needs to be gradual, use path-based splitting:

```yaml
# HTTPRoute: route /v2/* to new service, everything else falls through to Ingress
spec:
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /v2
    backendRefs:
    - name: api-v2
      port: 8080
```

---

## EPILOGUE

*"Don't run two routing systems for the same hostname. During Ingress-to-Gateway-API migrations, migrate one hostname at a time, completely. Half-migrated routes produce unpredictable, client-dependent behaviour."*

> **Inspector Ahmed's Rule #59:** Inconsistent routing for the same hostname? Check for both Ingress and HTTPRoute claiming it. Migrate completely. One hostname, one routing system.
