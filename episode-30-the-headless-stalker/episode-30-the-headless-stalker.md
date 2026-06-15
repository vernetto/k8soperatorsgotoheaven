# Episode 30 — "The Headless Stalker"
### *Inspector Ahmed and the StatefulSet that loses track of its pods*

**Culprit:** Headless service misconfigured — StatefulSet pods can't find each other
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `statefulset` `headless-service` `dns` `clustering`

---

## OPENING — Crime scene

"A distributed database was being deployed as a StatefulSet. The pods started, but they couldn't form a cluster — each pod thought it was alone. The error: nodes couldn't resolve each other's hostnames."

```bash
kubectl get pods -n database
```

```
NAME          READY   STATUS    RESTARTS   AGE
cassandra-0   1/1     Running   0          5m
cassandra-1   1/1     Running   0          4m
cassandra-2   1/1     Running   0          3m
```

All running. But the Cassandra logs show:

```bash
kubectl logs cassandra-1 -n database | grep ERROR
```

```
ERROR Unable to connect to seeds: cassandra-0.cassandra.database.svc.cluster.local
      java.net.UnknownHostException: cassandra-0.cassandra.database.svc.cluster.local
```

`cassandra-0` can't be resolved by `cassandra-1`.

> **📚 Teaching moment — Headless Services and StatefulSet DNS**
>
> StatefulSets give pods stable DNS names: `<pod-name>.<service-name>.<namespace>.svc.cluster.local`
>
> But this only works if the Service is **headless** — defined with `clusterIP: None`. A headless service doesn't get a VIP — instead, DNS returns the pod IPs directly, one per pod.
>
> Without `clusterIP: None`, the DNS returns only the Service VIP (which load-balances to a random pod) and individual pod hostnames are not registered.

---

## ACT I — The service spec

```bash
kubectl get svc cassandra -n database -o yaml | grep clusterIP
```

```
clusterIP: 10.96.144.22
```

Not headless. The service has a ClusterIP. Individual pod DNS names aren't registered.

---

## ACT II — Fix the service

```bash
kubectl delete svc cassandra -n database
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: cassandra
  namespace: database
spec:
  clusterIP: None          # headless
  selector:
    app: cassandra
  ports:
  - port: 9042
    name: cql
EOF
```

```bash
kubectl exec cassandra-0 -n database -- \
  nslookup cassandra-1.cassandra.database.svc.cluster.local
```

```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      cassandra-1.cassandra.database.svc.cluster.local
Address 1: 10.244.2.15 cassandra-1.cassandra.database.svc.cluster.local
```

Pods can now find each other. Cassandra forms its cluster.

---

## EPILOGUE

*"StatefulSet pod DNS only works with a headless service. If you forget `clusterIP: None`, individual pod hostnames don't resolve. Every distributed database, every peer-to-peer StatefulSet needs a headless service. No exceptions."*

> **Inspector Ahmed's Rule #30:** StatefulSet pods can't find each other by hostname? Check `clusterIP` on their governing service. It must be `None`.
