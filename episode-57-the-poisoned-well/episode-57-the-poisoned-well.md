# Episode 57 — "The Poisoned Well"
### *Inspector Ahmed and the node DNS cache that lies*

**Culprit:** NodeLocal DNSCache returning stale/incorrect records — service unreachable by name
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `dns` `nodelocaldns` `cache` `coredns` `networking`

---

## OPENING — Crime scene

"A service had been renamed and redeployed. The old name was gone. The new name worked from most pods. But pods on one specific node kept resolving the old IP — an IP that no longer existed. Stale DNS."

```bash
# From pod on node-2:
kubectl exec test-pod-node2 -- nslookup api-service.production.svc.cluster.local
```

```
Name:    api-service.production.svc.cluster.local
Address: 10.96.55.201   ← old ClusterIP, service deleted
```

```bash
# From pod on node-1:
kubectl exec test-pod-node1 -- nslookup api-service.production.svc.cluster.local
```

```
Name:    api-service.production.svc.cluster.local
Address: 10.96.88.44    ← correct new ClusterIP
```

Different answers from different nodes. The DNS cache on node-2 is stale.

---

## ACT I — NodeLocal DNSCache

```bash
kubectl get pods -n kube-system -o wide | grep node-local-dns
```

```
node-local-dns-xk2p    1/1   Running   0   node-1   45d
node-local-dns-r8tn    1/1   Running   0   node-2   45d
```

NodeLocal DNSCache runs as a DaemonSet and caches DNS responses locally on each node to reduce latency and load on CoreDNS. But the cache TTL can serve stale records if a service is deleted and recreated quickly.

```bash
kubectl logs node-local-dns-r8tn -n kube-system | grep api-service | tail -5
```

```
[INFO] Serving cached response for api-service.production.svc.cluster.local A 10.96.55.201 (TTL: 18s)
```

Serving a cached response with 18 seconds TTL remaining. The old service was deleted and new one created within the cache window.

> **📚 Teaching moment — NodeLocal DNSCache TTL**
>
> NodeLocal DNSCache caches responses with a TTL inherited from CoreDNS (typically 30 seconds for successful lookups). If a Service ClusterIP changes (e.g. service deleted and recreated) within the TTL window, cached records point to the old IP.
>
> When the old IP is unreachable, pods on nodes with stale caches get connection failures until the TTL expires and a fresh lookup is performed.

---

## ACT II — Clearing the cache

```bash
# Restart NodeLocal DNSCache pod on the affected node
kubectl delete pod node-local-dns-r8tn -n kube-system
# DaemonSet recreates it immediately with empty cache
```

Within seconds, pods on node-2 get the correct DNS response.

Long-term: if rapid service recreation is a pattern, reduce the DNS cache TTL:

```bash
kubectl edit configmap node-local-dns -n kube-system
# Change TTL from 30s to 5s for cluster.local zone
```

---

## EPILOGUE

*"NodeLocal DNSCache speeds up DNS — but it can serve stale records when services change rapidly. If DNS resolution gives different answers from different nodes, suspect the local cache. Restart the DaemonSet pod on the affected node."*

> **Inspector Ahmed's Rule #57:** Same DNS query, different answers from different nodes? NodeLocal DNSCache serving stale records. Restart the `node-local-dns` pod on the affected node. Cache clears instantly.
