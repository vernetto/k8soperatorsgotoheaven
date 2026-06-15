# Episode 22 — "The Haunted ConfigMap"
### *Inspector Ahmed and the configuration that never updates*

**Culprit:** App reads ConfigMap at startup only — mounted volume not reloaded
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `configmap` `volumes` `hot-reload` `configuration`

---

## OPENING — Crime scene

"The team had updated the ConfigMap. Verified the new value was there. Watched the mounted file update inside the pod. But the application kept using the old value. The change had arrived — and been ignored."

```bash
kubectl get configmap app-config -n production -o yaml | grep log_level
```

```
  log_level: "debug"
```

The ConfigMap says `debug`. The application is still logging at `info`. The volume mount shows the new value:

```bash
kubectl exec api-7f9d4b-xk2p -n production -- cat /etc/config/log_level
```

```
debug
```

The file is updated. The app ignores it.

> **📚 Teaching moment — ConfigMap volume updates**
>
> When a ConfigMap is mounted as a volume, Kubernetes *does* update the files inside the running pod — typically within 1-2 minutes (controlled by `kubelet`'s sync period). So the file on disk changes.
>
> But whether the *application* picks up that change depends entirely on the application code. Most applications read configuration once at startup and cache it. Unless the app has explicit file-watch logic (using `inotify` or periodic re-reads), it will never notice the file changed.
>
> **Environment variables from ConfigMaps are even more static** — they are set at pod creation and never change, even if the ConfigMap is updated. A pod restart is always required for env var changes.

---

## ACT II — The options

**Option A — Restart the deployment** (simple, always works):
```bash
kubectl rollout restart deployment/api -n production
```

**Option B — Implement config hot-reloading in the application:**
Use a file watcher library appropriate to your language:
- Go: `fsnotify`
- Node.js: `chokidar` or `fs.watch`
- Java: Spring Cloud Config with `@RefreshScope`
- Python: `watchdog`

**Option C — Use environment variables and accept that a restart is required for config changes** (simplest mental model):
```yaml
envFrom:
- configMapRef:
    name: app-config
```

The team chooses Option A for now and adds a note to implement Option B in the next sprint.

---

## EPILOGUE

*"ConfigMap volumes update the file on disk. They do not update the application's memory. Unless your app watches the file for changes, you need to restart the pods after a ConfigMap update. Know which kind of app you're running."*

> **Inspector Ahmed's Rule #22:** Updated ConfigMap but app uses old value? The file changed — the app didn't read it. Restart pods for env var changes (always required). Add file-watch logic for live reload. Know which you need.
