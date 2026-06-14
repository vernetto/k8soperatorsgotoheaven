# Episode 76 — "The Topology Mismatch"
### *Inspector Ahmed and the service that routes to wrong zones*

**Culprit:** Service topology routing misconfigured — cross-zone traffic causing latency and data sovereignty issues
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `topology` `service` `traffic-policy` `zones` `latency`

---

## OPENING — Crime scene

"Response latency had doubled since the cluster expanded to three availability zones. Profiling showed database queries from one zone were hitting a database replica in another zone — 80ms extra per query. The service was routing traffic cross-zone unnecessarily."

```bash
kubectl get svc database-svc -n production -o yaml | grep topology
```

```
(no output)
```

No topology configuration. The service distributes traffic across all endpoints regardless of zone.

---

## ACT I — Zone-aware routing

```bash
kubectl get endpoints database-svc -n production
```

```
NAME            ENDPOINTS
database-svc    10.244.1.5:5432,10.244.2.8:5432,10.244.3.12:5432
```

Three endpoints — one in each zone. Without topology routing, a pod in zone-a might get routed to the endpoint in zone-c, adding 80ms of inter-zone latency.

> **📚 Teaching moment — Topology Aware Hints**
>
> Kubernetes supports zone-aware routing via **Topology Aware Hints** (stable in 1.27). When enabled, kube-proxy prefers endpoints in the same zone as the requesting pod.
>
> Enable by adding an annotation to the Service:
> ```yaml
> metadata:
>   annotations:
>     service.kubernetes.io/topology-mode: Auto
> ```
>
> Requirements:
> - Nodes must have `topology.kubernetes.io/zone` labels
> - Endpoints must be roughly balanced across zones
> - At least one endpoint per zone
>
> The `externalTrafficPolicy: Local` is different — it affects external traffic to NodePort/LoadBalancer services, not internal pod-to-pod traffic.

---

## ACT II — Enabling topology hints

```bash
kubectl annotate svc database-svc -n production \
  service.kubernetes.io/topology-mode=Auto
```

After applying, kube-proxy updates endpoint slices with zone hints. Pods in zone-a preferentially route to the zone-a database replica.

```bash
kubectl get endpointslices -n production -l kubernetes.io/service-name=database-svc -o yaml | \
  grep -A 3 "hints:"
```

```yaml
hints:
  forZones:
  - name: eu-west-1a
```

Latency drops back to baseline. Database queries stay within-zone.

---

## EPILOGUE

*"Cross-zone traffic is slow and often costs money. Enable topology-aware routing for latency-sensitive services. One annotation. Kube-proxy does the rest. Check that your nodes have zone labels first."*

> **Inspector Ahmed's Rule #76:** High latency on internal service calls in multi-zone clusters? Add `service.kubernetes.io/topology-mode: Auto` annotation. Pods route to same-zone endpoints. Check node zone labels first.
