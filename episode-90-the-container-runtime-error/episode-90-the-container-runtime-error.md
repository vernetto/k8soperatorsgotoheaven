# Episode 90 — "The Container Runtime Error"
### *Inspector Ahmed and the pod that fails before any code runs*

**Culprit:** `RunContainerError` — container filesystem or mount configuration error
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `runcontainererror` `createcontainererror` `mounts` `configmap` `secrets`

---

## OPENING — Crime scene

"The image pulled successfully. The container was created. But it never started. The status was `CreateContainerConfigError` — not a crash, not an image error. Something was wrong before the code even ran."

```bash
kubectl get pods -n production
```

```
NAME                   READY   STATUS                       RESTARTS   AGE
api-7f9d4b-xk2p        0/1     CreateContainerConfigError   0          5m
```

`CreateContainerConfigError`. This status appears when Kubernetes can create the container spec but fails to configure it — typically due to a missing Secret or ConfigMap that was supposed to be mounted.

---

## ACT I — Reading the error

```bash
kubectl describe pod api-7f9d4b-xk2p -n production
```

```
Events:
  Warning  Failed    5m  kubelet
    Error: configmap "app-settings" not found
```

ConfigMap `app-settings` doesn't exist in the `production` namespace.

```bash
kubectl get configmap app-settings -n production
```

```
Error from server (NotFound): configmaps "app-settings" not found
```

```bash
kubectl get configmap app-settings --all-namespaces
```

```
NAMESPACE   NAME           DATA   AGE
default     app-settings   5      90d
```

The ConfigMap is in `default`. The pod is in `production`. Namespace isolation strikes again.

> **📚 Teaching moment — CreateContainerConfigError vs ErrImagePull**
>
> Key pre-start error statuses:
> - **ErrImagePull / ImagePullBackOff**: image can't be pulled
> - **CreateContainerConfigError**: container spec references a missing Secret or ConfigMap
> - **CreateContainerError**: container could be configured but failed to start (often a permission or entrypoint error)
> - **RunContainerError**: container started but immediately exited (often a command not found)
>
> `CreateContainerConfigError` is always about missing mounted Secrets or ConfigMaps. Check `kubectl describe pod` → Events.

---

## ACT II — Fix

```bash
# Copy ConfigMap to production namespace
kubectl get configmap app-settings -n default -o yaml \
  | grep -v '^\s*namespace:' \
  | kubectl apply -n production -f -
```

```bash
kubectl get pods -n production
```

```
NAME                   READY   STATUS    RESTARTS   AGE
api-7f9d4b-xk2p        1/1     Running   0          5m
```

---

## EPILOGUE

*"CreateContainerConfigError always means a missing Secret or ConfigMap that the pod spec references. It won't even try to run your code until this is resolved. Check the Events — the error message names the exact resource."*

> **Inspector Ahmed's Rule #90:** `CreateContainerConfigError`? A Secret or ConfigMap is missing in the pod's namespace. Read the Events for the resource name. Create it in the right namespace.
