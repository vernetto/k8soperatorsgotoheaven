# Episode 60 — "The Race in the Dark"
### *Inspector Ahmed and two containers fighting over one file*

**Culprit:** Two containers in same pod writing to shared emptyDir volume without coordination
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `emptydir` `shared-volumes` `multi-container` `race-condition`

---

## OPENING — Crime scene

"The pod had two containers sharing a volume. Both were writing configuration. The application kept reading corrupted config files and crashing. Not every time — sometimes. The worst kind of bug."

```bash
kubectl get pod dual-container-7f9d-xk2p -n production
```

```
NAME                         READY   STATUS             RESTARTS   AGE
dual-container-7f9d-xk2p     2/2     CrashLoopBackOff   22         1h
```

22 restarts. But not always crashing — sometimes it runs for minutes before dying.

---

## ACT I — The shared volume

```bash
kubectl get pod dual-container-7f9d-xk2p -n production -o yaml | grep -A 20 "volumes:"
```

```yaml
volumes:
- name: config-share
  emptyDir: {}

containers:
- name: config-writer
  volumeMounts:
  - name: config-share
    mountPath: /shared/config

- name: app
  volumeMounts:
  - name: config-share
    mountPath: /etc/app/config
```

Both containers share the same `emptyDir` volume. `config-writer` writes the configuration file. `app` reads it.

```bash
kubectl logs dual-container-7f9d-xk2p -c app -n production | grep "config error"
```

```
[ERROR] Failed to parse config: unexpected end of JSON input
[ERROR] Failed to parse config: unexpected end of JSON input
```

Truncated JSON. The `app` container is reading the config file while `config-writer` is in the middle of writing it — before the write is complete. Race condition.

> **📚 Teaching moment — Safe shared volume patterns**
>
> emptyDir volumes have no locking mechanism. If two containers write to the same file simultaneously, corruption occurs.
>
> Safe patterns:
> 1. **Write to a temp file, then atomic rename**: `config-writer` writes to `/shared/config.tmp`, then `mv /shared/config.tmp /shared/config`. `mv` is atomic on the same filesystem.
> 2. **Use an init container** to write config before the main container starts (if config is static).
> 3. **Use a sidecar with coordination**: write to separate files per writer, have a coordinator merge them.
> 4. **Use ConfigMaps** for config that doesn't change at runtime.

---

## ACT II — The atomic write fix

The `config-writer` container is updated to use atomic writes:

```bash
# In config-writer container script
generate_config > /shared/config.new
mv /shared/config.new /shared/config    # atomic rename
```

The race condition is eliminated. The app either reads the complete old config or the complete new config — never a partial one.

---

## EPILOGUE

*"Shared volumes between containers have no built-in locking. Write to a temp file, then rename atomically. Or use init containers for static config. Never let two processes write to the same file without coordination."*

> **Inspector Ahmed's Rule #60:** Intermittent config corruption in a multi-container pod? Check shared volumes. Use atomic rename (`mv tmp target`) to prevent race conditions. Intermittent = race condition. Always.
