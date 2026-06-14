# Episode 47 — "The Half-Open Door"
### *Inspector Ahmed and the NodePort that works from some places but not others*

**Culprit:** NodePort accessible on some nodes but not others — kube-proxy not running on a node
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `nodeport` `kube-proxy` `networking` `iptables`

---

## OPENING — Crime scene

"The LoadBalancer service was supposedly healthy. Requests from EU worked. Requests from US didn't. The health checks on the cloud LB showed some nodes healthy, some unhealthy. Ahmed traced the traffic."

```bash
kubectl get svc api-service -n production
```

```
NAME          TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)         AGE
api-service   LoadBalancer   10.96.55.201    203.0.113.42    8080:31042/TCP  30d
```

NodePort 31042. Ahmed tests directly:

```bash
# Works:
curl http://node-1:31042/health
# {"status":"ok"}

# Fails:
curl http://node-3:31042/health
# Connection refused
```

The NodePort works on node-1 and node-2, but not node-3. The cloud LB marks node-3 as unhealthy and routes US traffic (which hits EU nodes) fine — but the LB is misconfigured to include node-3 in the US target group.

---

## ACT I — kube-proxy on node-3

NodePort routing is handled by `kube-proxy`, which configures iptables rules on each node. If kube-proxy isn't running on a node, that node won't have the rules and NodePort traffic will be refused.

```bash
kubectl get pods -n kube-system -o wide | grep kube-proxy
```

```
NAME                READY   STATUS    NODE     AGE
kube-proxy-xk2p     1/1     Running   node-1   30d
kube-proxy-r8tn     1/1     Running   node-2   30d
kube-proxy-9lmw     0/1     Error     node-3   2h
```

kube-proxy on node-3 is in Error state. Without it, no iptables rules are set, and all NodePort/ClusterIP traffic to/from that node is broken.

```bash
kubectl logs kube-proxy-9lmw -n kube-system
```

```
E0314 Failed to run kube-proxy: iptables: No chain/target/match
  by that name. Run 'iptables --list' as root for more information.
```

iptables chain corruption on node-3. Possibly caused by a node update that reset iptables rules while kube-proxy was running.

---

## ACT II — The fix

```bash
# SSH to node-3
iptables --flush
iptables -t nat --flush
iptables -t mangle --flush
iptables -X

# Restart kube-proxy
kubectl delete pod kube-proxy-9lmw -n kube-system
# DaemonSet will restart it automatically
```

kube-proxy restarts, rebuilds all iptables rules:

```bash
curl http://node-3:31042/health
```

```
{"status":"ok"}
```

---

## EPILOGUE

*"kube-proxy is the networking brain on every node. If it's not running on a node, that node can't route Kubernetes service traffic. Always check kube-proxy status when NodePort or ClusterIP traffic is broken on a specific node."*

> **Inspector Ahmed's Rule #47:** NodePort works on some nodes but not others? Check kube-proxy DaemonSet. `kubectl get pods -n kube-system -o wide | grep kube-proxy`. Find the broken one. Restart it.
