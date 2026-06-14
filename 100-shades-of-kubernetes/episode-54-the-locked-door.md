# Episode 54 — "The Locked Door"
### *Inspector Ahmed and the volume that mounts but refuses writes*

**Culprit:** Wrong fsGroup — container runs as non-root but volume is owned by root
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `securitycontext` `fsgroup` `permissions` `volumes` `nonroot`

---

## OPENING — Crime scene

"The pod was running. The volume was mounted. The application started — and immediately crashed when it tried to write its first log file to the mounted volume. Permission denied."

```bash
kubectl logs app-7f9d4b-xk2p -n production
```

```
[ERROR] Failed to open log file /data/app.log:
        open /data/app.log: permission denied
[FATAL] Cannot initialise logging subsystem. Exiting.
```

```bash
kubectl exec app-7f9d4b-xk2p -n production -- ls -la /data
```

```
total 4
drwxr-xr-x 2 root root 4096 Mar 14 10:00 .
drwxr-xr-x 1 root root 4096 Mar 14 10:00 ..
```

The `/data` directory is owned by `root:root`. The container runs as a non-root user and can't write to it.

---

## ACT I — The security context

```bash
kubectl get pod app-7f9d4b-xk2p -n production -o yaml | grep -A 10 "securityContext"
```

```yaml
spec:
  securityContext: {}
  containers:
  - name: app
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
```

The container runs as user 1000. The volume directory is owned by root. No `fsGroup` is set.

> **📚 Teaching moment — fsGroup**
>
> When Kubernetes mounts a volume, it can change the ownership of the volume's files to a specific group. This is controlled by `fsGroup` in the pod-level `securityContext`.
>
> If `fsGroup: 1000` is set:
> - Kubernetes runs `chown :1000` on the volume mount point
> - All files created in the volume will have group ownership 1000
> - A container running as user 1000 (which is in group 1000 by default) can read and write
>
> Without `fsGroup`, volumes are owned by root, and non-root containers can't write to them.

---

## ACT II — Adding fsGroup

```yaml
spec:
  securityContext:
    fsGroup: 1000        # volume ownership group
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: app
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      allowPrivilegeEscalation: false
```

After applying and restarting:

```bash
kubectl exec app-8a2b1c-xk2p -n production -- ls -la /data
```

```
total 4
drwxrwsr-x 2 root 1000 4096 Mar 14 10:05 .
```

Group ownership is now 1000. The container can write.

---

## EPILOGUE

*"Non-root containers and writable volumes need fsGroup. Without it, the volume is owned by root and your container silently fails to write. Always set fsGroup equal to your container's runAsUser when using persistent volumes with non-root workloads."*

> **Inspector Ahmed's Rule #54:** `permission denied` on a mounted volume for a non-root container? Add `fsGroup` to the pod securityContext. Set it to the same value as `runAsUser`.
