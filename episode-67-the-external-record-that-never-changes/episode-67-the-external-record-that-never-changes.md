# Episode 67 — "The External Record That Never Changes"
### *Inspector Ahmed and the DNS that forgot to follow the service*

**Culprit:** ExternalDNS not updating external records — missing annotation on Service
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `externaldns` `dns` `annotations` `ingress` `loadbalancer`

---

## OPENING — Crime scene

"The load balancer IP had changed after a cluster migration. The Kubernetes Service was updated. But external DNS still pointed to the old IP. External users were hitting a dead address. ExternalDNS was installed — but not watching this service."

```bash
dig api.example.com
```

```
;; ANSWER SECTION:
api.example.com.    300    IN    A    203.0.113.42
```

Old IP. The LoadBalancer now has a new IP:

```bash
kubectl get svc api-service -n production
```

```
NAME          TYPE           CLUSTER-IP    EXTERNAL-IP     PORT(S)
api-service   LoadBalancer   10.96.55.201  203.0.113.99    443:31042/TCP
```

`203.0.113.99` — new IP. DNS still shows the old `203.0.113.42`.

---

## ACT I — The missing annotation

ExternalDNS watches Services and Ingresses — but only those with the correct annotation:

```bash
kubectl get svc api-service -n production -o yaml | grep annotations -A 5
```

```yaml
annotations:
  kubernetes.io/ingress.class: nginx
```

No ExternalDNS annotation. The service exists but ExternalDNS is ignoring it.

> **📚 Teaching moment — ExternalDNS annotation**
>
> ExternalDNS can operate in two modes:
> - **annotation-based** (opt-in): only manages records for resources with `external-dns.alpha.kubernetes.io/hostname` annotation
> - **source-based** (opt-out): manages all LoadBalancer Services and Ingresses, unless filtered
>
> In annotation mode (common in multi-team clusters):
> ```yaml
> annotations:
>   external-dns.alpha.kubernetes.io/hostname: api.example.com
>   external-dns.alpha.kubernetes.io/ttl: "300"
> ```
>
> Without the annotation, ExternalDNS doesn't know it should manage this record.

---

## ACT II — Adding the annotation

```bash
kubectl annotate svc api-service -n production \
  external-dns.alpha.kubernetes.io/hostname=api.example.com \
  external-dns.alpha.kubernetes.io/ttl=300
```

Within one ExternalDNS sync interval (default: 1 minute):

```bash
dig api.example.com
```

```
;; ANSWER SECTION:
api.example.com.    300    IN    A    203.0.113.99
```

Updated.

---

## EPILOGUE

*"ExternalDNS is automatic — but only for what you tell it to watch. Add the hostname annotation to every Service and Ingress that should have external DNS records. Without it, ExternalDNS is blind to the service."*

> **Inspector Ahmed's Rule #67:** External DNS not updating after LB IP change? Check for `external-dns.alpha.kubernetes.io/hostname` annotation on the Service. Add it if missing. ExternalDNS only manages annotated resources.
