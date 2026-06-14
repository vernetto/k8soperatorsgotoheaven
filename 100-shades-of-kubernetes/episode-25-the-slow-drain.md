# Episode 25 — "The Slow Drain"
### *Inspector Ahmed and the rolling update that breaks connections*

**Culprit:** No preStop hook — load balancer sends traffic to terminating pods
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `rolling-update` `prestop` `connections` `graceful-drain` `502`

---

## OPENING — Crime scene

"Every deploy produced exactly 30 seconds of 502 errors. Not before the new pods started — during the transition. The new pods were healthy. But the old pods were getting traffic while they were being killed."

This is a race condition. The load balancer and the pod lifecycle are out of sync.

---

## ACT I — The race

When a rolling update happens:

1. New pod starts, passes readiness probe → added to Service endpoints
2. Old pod gets `SIGTERM` → starts shutting down
3. Kubernetes removes old pod from Service endpoints **after** sending SIGTERM
4. But the cloud load balancer (AWS ALB, GCP LB) has its own endpoint cache — it can take 5–30 seconds to stop sending traffic to the old pod
5. During those seconds: old pod is dying, but still receiving traffic → 502s

> **📚 Teaching moment — The endpoint propagation delay**
>
> When a pod is removed from Service endpoints, the change propagates through several components:
> - kube-proxy on each node updates iptables/IPVS rules
> - Cloud load balancer target group / backend service updates its pool
>
> This propagation takes time — often 10–30 seconds for cloud LBs. During this window, traffic still arrives at the terminating pod.
>
> The fix: add a `preStop` sleep hook to delay the actual shutdown, giving the load balancer time to drain.

---

## ACT II — The preStop hook

```yaml
lifecycle:
  preStop:
    exec:
      command: ["/bin/sh", "-c", "sleep 15"]
```

With this hook:
1. Kubernetes calls `preStop` before sending SIGTERM
2. The pod sleeps 15 seconds — still alive, still serving traffic
3. Load balancer has time to drain connections and stop routing to this pod
4. After 15 seconds, `preStop` exits, Kubernetes sends SIGTERM, pod shuts down cleanly

Also increase `terminationGracePeriodSeconds` to cover `preStop` time + app shutdown time:

```yaml
terminationGracePeriodSeconds: 60
```

Next deploy: zero 502 errors.

---

## EPILOGUE

*"The load balancer and Kubernetes don't talk to each other directly. The LB learns about pod removal through endpoint propagation — which takes time. A preStop sleep bridges that gap. 15 seconds of sleep saves 30 seconds of errors."*

> **Inspector Ahmed's Rule #25:** 502s during rolling updates = load balancer still routing to terminating pods. Add a `preStop: sleep 15` hook. It's the simplest fix in Kubernetes.
