# Episode 38 — "The Forbidden Fruit"
### *Inspector Ahmed and the PodSecurityPolicy that blocks a legitimate container*

**Culprit:** PodSecurityPolicy (or Pod Security Admission) blocks privileged operations needed by a DaemonSet
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `podsecurity` `psa` `privileged` `daemonset` `security`

---

## OPENING — Crime scene

"A monitoring DaemonSet was deployed to collect node metrics. It needed to run privileged — to access `/proc` and host network. The pods were created, but immediately failed. A security policy was standing in the way."

```bash
kubectl get pods -n monitoring -o wide
```

```
NAME                    READY   STATUS    RESTARTS   NODE     AGE
node-exporter-xk2p      0/1     Error     3          node-1   5m
```

```bash
kubectl logs node-exporter-xk2p -n monitoring
```

```
Error: failed to create fsnotify watcher: too many open files
level=error msg="Error opening /host/proc/net/dev: permission denied"
```

Permission denied accessing `/host/proc`. The container needs host-level access it's not getting.

---

## ACT I — The security policy

```bash
kubectl describe pod node-exporter-xk2p -n monitoring | grep -i "security\|privileged"
```

```
Security Context:
  AllowPrivilegeEscalation: false
  RunAsNonRoot: true
  SeccompProfile: RuntimeDefault
```

The cluster has Pod Security Admission enforcing `restricted` policy on all namespaces, including monitoring. The `restricted` policy disallows privileged containers and host path mounts.

> **📚 Teaching moment — Pod Security Admission (PSA)**
>
> PSA replaced PodSecurityPolicy (deprecated in 1.21, removed in 1.25). It enforces three built-in policies:
> - **privileged**: no restrictions
> - **baseline**: blocks the most dangerous capabilities (no host namespaces, no privileged containers)
> - **restricted**: heavily restricted — non-root, no privilege escalation, minimal capabilities
>
> Policies are applied per-namespace via labels:
> ```
> pod-security.kubernetes.io/enforce: restricted
> pod-security.kubernetes.io/enforce-version: latest
> ```
>
> System and monitoring namespaces often need to be `privileged` or `baseline`, not `restricted`.

---

## ACT II — The fix

The monitoring namespace should use `privileged` policy since node exporters legitimately need host access:

```bash
kubectl label namespace monitoring \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/enforce-version=latest \
  --overwrite
```

Or, more cautiously, use `baseline` and add only the specific capabilities needed in the pod spec:

```yaml
securityContext:
  capabilities:
    add: ["SYS_PTRACE"]
hostPID: true
hostNetwork: true
```

After applying the namespace label change:

```bash
kubectl rollout restart daemonset/node-exporter -n monitoring
kubectl get pods -n monitoring
```

```
NAME                    READY   STATUS    RESTARTS   NODE     AGE
node-exporter-mn2xp     1/1     Running   0          node-1   20s
```

---

## EPILOGUE

*"Security policies protect the cluster — but they also break legitimate workloads if applied without exceptions. DaemonSets that monitor nodes will always need elevated privileges. Give them a dedicated namespace with appropriate security levels."*

> **Inspector Ahmed's Rule #38:** System and monitoring DaemonSets often need `privileged` or `baseline` PSA. Give them a dedicated namespace labeled accordingly. Don't fight the security policy — configure it correctly per namespace.
