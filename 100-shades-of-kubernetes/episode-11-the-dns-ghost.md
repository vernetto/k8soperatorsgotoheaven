# Episode 11 — "The DNS Ghost"
### *Inspector Ahmed and the hostname that resolves to nothing*

**Culprit:** CoreDNS pod crashing — cluster-internal DNS broken
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `dns` `coredns` `networking` `service-discovery`

---

## OPENING — Crime scene

"Everything was running. Pods healthy. Services present. But no service could talk to any other service by name. Every connection attempt returned `Name or service not known`. The cluster had gone deaf."

```bash
kubectl exec -it frontend-6d8f9-xk2p -n production -- \
  curl http://backend-api:8080/health
```

```
curl: (6) Could not resolve host: backend-api
```

Name resolution failure. Ahmed doesn't touch the application. He goes straight to the DNS infrastructure.

---

## ACT I — Checking CoreDNS

```bash
kubectl get pods -n kube-system | grep coredns
```

```
NAME                       READY   STATUS             RESTARTS   AGE
coredns-5d78c9869d-4xk2p   0/1     CrashLoopBackOff   14         1h
coredns-5d78c9869d-r8tn1   0/1     CrashLoopBackOff   11         1h
```

Both CoreDNS pods are crashing. With no DNS, service names can't resolve — which is why every microservice communication is failing.

> **📚 Teaching moment — How Kubernetes DNS works**
>
> Every pod in Kubernetes gets `/etc/resolv.conf` configured to point to the cluster DNS (CoreDNS). When your app does `http://backend-api:8080`, the OS resolves `backend-api` to `backend-api.production.svc.cluster.local` via CoreDNS. CoreDNS looks it up in Kubernetes service records and returns the ClusterIP.
>
> If CoreDNS is down, every service-name-based connection fails. IP-based connections still work — which can help isolate the problem.

---

## ACT II — Reading the CoreDNS logs

```bash
kubectl logs coredns-5d78c9869d-4xk2p -n kube-system --previous
```

```
[FATAL] plugin/errors: 2 SERVFAIL response. Proxy loop detected
[FATAL] Shutting down
```

Proxy loop. CoreDNS is configured to forward queries to an upstream DNS server — and that upstream is pointing back at CoreDNS itself, creating an infinite loop.

```bash
kubectl describe configmap coredns -n kube-system
```

```yaml
.:53 {
    errors
    health
    kubernetes cluster.local in-addr.arpa ip6.arpa {
      pods insecure
      fallthrough in-addr.arpa ip6.arpa
    }
    forward . /etc/resolv.conf
    cache 30
    loop
    reload
    loadbalance
}
```

The `forward . /etc/resolv.conf` line tells CoreDNS to forward unknown queries to the node's `/etc/resolv.conf`. On this cluster, the node's `/etc/resolv.conf` points to the cluster DNS IP — which is CoreDNS. Loop.

---

## ACT III — The fix

```bash
kubectl edit configmap coredns -n kube-system
```

Replace the forward directive with explicit upstream DNS servers:

```yaml
forward . 8.8.8.8 8.8.4.4
```

```bash
kubectl rollout restart deployment/coredns -n kube-system
kubectl get pods -n kube-system | grep coredns
```

```
NAME                       READY   STATUS    RESTARTS   AGE
coredns-7b96bf9f76-p8t2n   1/1     Running   0          30s
coredns-7b96bf9f76-xk1m9   1/1     Running   0          28s
```

```bash
kubectl exec -it frontend-6d8f9-xk2p -n production -- \
  curl http://backend-api:8080/health
```

```
{"status":"ok"}
```

---

## EPILOGUE

*"When all services fail to talk to each other at the same time, suspect DNS before anything else. CoreDNS is the backbone of Kubernetes service discovery. When it falls, the whole cluster goes silent."*

> **📚 Episode takeaways**
>
> | Command | What it's for |
> |---|---|
> | `kubectl get pods -n kube-system \| grep coredns` | Check CoreDNS health |
> | `kubectl logs coredns-... -n kube-system` | Find the DNS error |
> | `kubectl describe configmap coredns -n kube-system` | Check DNS forwarding config |
>
> **Inspector Ahmed's Rule #11:** Mass service-to-service failure = DNS first. Check CoreDNS before touching any application.
