# Episode 55 — "The Invisible Egress"
### *Inspector Ahmed and the app that can't reach the internet*

**Culprit:** NetworkPolicy egress rule missing — pod can't make outbound connections
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `networkpolicy` `egress` `networking` `dns` `external`

---

## OPENING — Crime scene

"The payment service needed to call Stripe's API. The pod was running. The request was being made. And every call timed out. Not just Stripe — any external URL. The pod was trapped inside the cluster."

```bash
kubectl exec payment-7f9d4b-xk2p -n production -- \
  curl https://api.stripe.com/v1/charges --max-time 5
```

```
curl: (28) Connection timed out after 5001 milliseconds
```

```bash
kubectl exec payment-7f9d4b-xk2p -n production -- \
  curl http://1.1.1.1 --max-time 5
```

```
curl: (28) Connection timed out after 5001 milliseconds
```

Even a raw IP times out. Not DNS — the IP itself is unreachable.

---

## ACT I — The egress NetworkPolicy

```bash
kubectl get networkpolicy -n production
```

```
NAME              POD-SELECTOR   AGE
default-deny-all  <none>         10d
allow-internal    app=payment    10d
```

```bash
kubectl describe networkpolicy default-deny-all -n production
```

```
Spec:
  PodSelector: <none>
  Policy Types: Ingress, Egress
  Allowing ingress traffic: <none>
  Allowing egress traffic:  <none>
```

A default-deny policy on *both* Ingress and Egress. The `allow-internal` policy permits traffic within the cluster — but there's no egress rule allowing traffic to external IPs.

> **📚 Teaching moment — Egress NetworkPolicy**
>
> NetworkPolicy egress rules control outbound traffic from pods. When a default-deny-egress policy is applied, pods can't make any outbound connections unless explicitly allowed — including DNS lookups.
>
> A common mistake: adding egress to allow specific external IPs but forgetting to also allow DNS (port 53 to the cluster DNS IP or `kube-dns` namespace).

---

## ACT II — Adding egress rules

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-payment-egress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: payment
  policyTypes:
  - Egress
  egress:
  # Allow DNS
  - ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
  # Allow HTTPS to internet
  - ports:
    - port: 443
      protocol: TCP
  # Allow HTTP for health checks
  - ports:
    - port: 80
      protocol: TCP
```

```bash
kubectl apply -f allow-payment-egress.yaml
kubectl exec payment-7f9d4b-xk2p -n production -- \
  curl -s https://api.stripe.com/v1 -o /dev/null -w "%{http_code}"
```

```
200
```

---

## EPILOGUE

*"Egress NetworkPolicy is easy to forget. A deny-all policy blocks both directions. When adding egress allows, always include DNS (UDP/TCP 53) — otherwise even domain name resolution fails. Timeouts, not refused connections, are the signal."*

> **Inspector Ahmed's Rule #55:** Pod can't reach external IPs? Check for egress NetworkPolicy. Always allow port 53 (DNS) alongside application ports. Test with raw IP first to distinguish DNS failures from routing failures.
