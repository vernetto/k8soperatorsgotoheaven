# Episode 43 — "The Invisible ConfigMap"
### *Inspector Ahmed and the subPath mount that doesn't update*

**Culprit:** ConfigMap mounted with subPath — file updates are never propagated to the pod
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `configmap` `subpath` `volumes` `hot-reload`

---

## OPENING — Crime scene

"A developer updated the ConfigMap. Waited 2 minutes for the volume to propagate. Checked the mounted file — old content. Waited 10 minutes. Still old. The file would never update, because of a subtle mounting detail nobody had noticed."

```bash
kubectl get configmap app-config -n production -o yaml | grep config.yaml -A 3
```

```yaml
data:
  config.yaml: |
    log_level: debug
    timeout: 30s
```

Updated 10 minutes ago. But inside the pod:

```bash
kubectl exec api-7f9d4b-xk2p -n production -- cat /etc/config/config.yaml
```

```yaml
log_level: info
timeout: 10s
```

Old values. The mount is not updating.

---

## ACT I — The subPath culprit

```bash
kubectl get pod api-7f9d4b-xk2p -n production -o yaml | grep -A 20 "volumes\|volumeMounts"
```

```yaml
volumeMounts:
- name: config-volume
  mountPath: /etc/config/config.yaml
  subPath: config.yaml        # <-- here

volumes:
- name: config-volume
  configMap:
    name: app-config
```

`subPath: config.yaml`. When you use `subPath` to mount a single file from a ConfigMap, **Kubernetes does not update the file when the ConfigMap changes**. This is a known limitation — subPath mounts bypass the normal symlink mechanism that enables hot-reload.

> **📚 Teaching moment — subPath vs directory mount**
>
> Normal ConfigMap volume mount (directory): Kubernetes uses symlinks inside the volume. When the ConfigMap updates, the symlinks are atomically repointed to new files. The pod sees updated content within ~1-2 minutes.
>
> subPath mount: the file is copied directly at mount time. No symlink. No update propagation. Ever.
>
> Use subPath only when you need to mount a single file without overwriting an entire directory. Accept that it requires a pod restart on ConfigMap changes.

---

## ACT II — The fix

Remove the `subPath` and mount the whole directory instead:

```yaml
volumeMounts:
- name: config-volume
  mountPath: /etc/config/    # mount directory, not single file
```

Or, if subPath is required (to avoid overwriting other files in the directory), accept that a pod restart is needed after ConfigMap changes:

```bash
kubectl rollout restart deployment/api -n production
```

---

## EPILOGUE

*"subPath mounts are static snapshots. They will never update, no matter how long you wait. If you need live ConfigMap updates, mount the whole directory. If you use subPath, document that config changes require a pod restart."*

> **Inspector Ahmed's Rule #43:** ConfigMap file not updating inside pod? Check for `subPath` in the volumeMount. subPath mounts never auto-update. Remove subPath or accept a restart after config changes.
