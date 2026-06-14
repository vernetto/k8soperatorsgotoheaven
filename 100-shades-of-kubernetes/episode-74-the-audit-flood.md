# Episode 74 — "The Audit Flood"
### *Inspector Ahmed and the API server whose disk fills with requests*

**Culprit:** Audit logging misconfigured — logging every single API call at maximum verbosity
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `audit-logging` `api-server` `disk` `performance` `control-plane`

---

## OPENING — Crime scene

"The control plane node's disk was filling up at 10 GB per day. The API server was slow. The culprit: audit logging had been enabled six months ago with the 'log everything' policy — and nobody had thought about the volume."

```bash
# On control plane node
df -h /var/log
```

```
Filesystem      Size  Used Avail Use%
/dev/sda2        50G   47G   3G   94%
```

```bash
ls -lh /var/log/kubernetes/
```

```
-rw-r--r-- 1 root root 8.2G audit.log
-rw-r--r-- 1 root root 8.9G audit.log.1
-rw-r--r-- 1 root root 7.8G audit.log.2
```

8-9 GB per log file. The audit log rotation is set to 10 files — 80+ GB of audit logs.

---

## ACT I — The audit policy

```bash
cat /etc/kubernetes/audit-policy.yaml
```

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: RequestResponse   # log everything including request and response body
```

One rule: log everything at `RequestResponse` level. Every single API call, every request body, every response body. For a cluster with 50 pods and normal autoscaling, this generates millions of log entries per day.

> **📚 Teaching moment — Audit policy levels**
>
> Kubernetes audit policies support four levels per rule:
> - **None**: don't log this request
> - **Metadata**: log request metadata only (user, resource, verb, timestamp) — minimal size
> - **Request**: metadata + request body
> - **RequestResponse**: metadata + request body + response body — maximum size
>
> A good audit policy is selective:
> - `None` for high-frequency, low-risk calls (pod status updates, lease renewals, watch calls)
> - `Metadata` for most operations
> - `Request` or `RequestResponse` only for sensitive operations (secret reads, RBAC changes)

---

## ACT II — A focused audit policy

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived
rules:
# Don't log read-only requests to non-sensitive resources
- level: None
  verbs: ["get", "list", "watch"]
  resources:
  - group: ""
    resources: ["pods", "nodes", "services", "configmaps"]
  - group: "apps"
    resources: ["deployments", "replicasets"]

# Log secret access at RequestResponse level
- level: RequestResponse
  resources:
  - group: ""
    resources: ["secrets"]

# Log RBAC changes at RequestResponse level
- level: RequestResponse
  resources:
  - group: "rbac.authorization.k8s.io"
    resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]

# Everything else: metadata only
- level: Metadata
```

After applying the new policy, audit log volume drops from 8 GB/day to 200 MB/day.

---

## EPILOGUE

*"Audit logging is essential — but 'log everything at RequestResponse' is a disk disaster. Be selective. Log sensitive operations in detail (secrets, RBAC). Ignore or minimise routine operations (pod get, node watch). Your disk will thank you."*

> **Inspector Ahmed's Rule #74:** Control plane disk filling with audit logs? Read the audit policy. Replace `level: RequestResponse` for all traffic with a tiered policy: None for noisy reads, Metadata for most things, RequestResponse only for sensitive resources.
