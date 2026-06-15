# Episode 10 — "The Termination That Never Ends"
### *Inspector Ahmed and the pod that refuses to die gracefully*

**Culprit:** Application ignores SIGTERM — shell PID 1 doesn't forward signals
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `terminating` `sigterm` `graceful-shutdown` `pid1` `lifecycle`

---

## OPENING — Crime scene

"A rolling update had been running for twenty minutes. It should take two. Half the old pods were stuck in `Terminating`. The new ones were up and healthy. But the old ones were ghosts — neither alive nor dead."

```bash
kubectl get pods -n production
```

```
NAME                        READY   STATUS        RESTARTS   AGE
api-v1-7f9d4b-xk2p9         0/1     Terminating   0          22m
api-v1-7f9d4b-r8tn1         0/1     Terminating   0          20m
api-v2-9c2e1a-mn3kp         1/1     Running       0          3m
api-v2-9c2e1a-xr7wl         1/1     Running       0          2m
```

`Terminating` for 22 minutes. Something is preventing the graceful shutdown.

---

## ACT I — The shutdown sequence

```bash
kubectl describe pod api-v1-7f9d4b-xk2p9 -n production
```

```
Status:         Terminating (lasts 22m)
Termination Grace Period: 1800s
```

`terminationGracePeriodSeconds` is 1800 — 30 minutes. Someone set this thinking it would help with graceful draining. It means SIGKILL won't arrive for 30 minutes.

> **📚 Teaching moment — The pod termination sequence**
>
> When Kubernetes deletes a pod:
> 1. Sets the pod's `deletionTimestamp`
> 2. Executes the `preStop` hook (if defined)
> 3. Sends **SIGTERM** to PID 1 in each container
> 4. Waits up to `terminationGracePeriodSeconds` (default: 30s)
> 5. Sends **SIGKILL** if the process hasn't exited
>
> If PID 1 is a shell and the app doesn't handle SIGTERM, the pod stays alive for the full grace period.

---

## ACT II — The unresponsive process

```bash
kubectl exec api-v1-7f9d4b-xk2p9 -n production -- ps aux
```

```
PID   USER     COMMAND
1     root     /bin/sh -c ./start.sh
7     root     node server.js
```

PID 1 is `/bin/sh`. The shell script launched Node.js. When Kubernetes sends SIGTERM to PID 1 (the shell), the shell doesn't forward it to its child processes. Node.js never receives SIGTERM and keeps running.

---

## ACT III — The fix

**Immediate fix — force delete the stuck pods:**

```bash
kubectl delete pod api-v1-7f9d4b-xk2p9 -n production --grace-period=0 --force
```

**Proper fix — use exec form in the Dockerfile:**

```dockerfile
# Wrong — shell form, PID 1 is sh, signals not forwarded
CMD ./start.sh

# Correct — exec form, PID 1 is the actual process
CMD ["node", "server.js"]
```

**If you need a startup script, use `exec` to replace the shell:**

```bash
#!/bin/sh
# start.sh
export DATABASE_URL=$(get-secret db-url)
exec node server.js   # exec replaces sh — PID 1 becomes node
```

The team applies the Dockerfile fix and reduces `terminationGracePeriodSeconds` to 60. The next rolling update completes in 90 seconds.

---

## EPILOGUE

*"If PID 1 is a shell, signals get lost. The shell doesn't forward them. Your app never knows it should shut down. Use exec form in your Dockerfile. It's a one-character fix."*

> **📚 Episode takeaways**
>
> | Concept | Detail |
> |---|---|
> | Kubernetes sends SIGTERM to PID 1 | Not to all processes — only PID 1 |
> | Shell form `CMD ./script.sh` | PID 1 = shell — signals not forwarded |
> | Exec form `CMD ["node", "app.js"]` | PID 1 = your app — signals received |
> | `--grace-period=0 --force` | Emergency force-delete a stuck pod |
>
> **Inspector Ahmed's Rule #10:** A pod stuck in `Terminating` is almost always PID 1 not handling SIGTERM. Check `ps aux`. If PID 1 is a shell, fix the Dockerfile.
