# Episode 4 — "Death by a Thousand Requests"
### *Inspector Ahmed and the pod that keeps getting murdered*

**Culprit:** Memory limit too low — kernel OOM killer terminates the container
**Difficulty:** ⭐ Beginner
**Tags:** `oomkilled` `memory` `limits` `resources`

---

## OPENING — Crime scene

"Restarts: 8. Status: `OOMKilled`. Ahmed had seen this before. This wasn't a misconfiguration. This was a murder — and the killer was the Linux kernel."

```bash
kubectl get pods -n production
```

```
NAME                         READY   STATUS      RESTARTS   AGE
worker-processor-7d9f-kp2l   0/1     OOMKilled   8          3h
```

`OOMKilled`. Not `CrashLoopBackOff` — though it will become that eventually. Right now, the status is telling Ahmed directly: the pod was killed by the Out Of Memory killer. No ambiguity.

---

## ACT I — The autopsy

```bash
kubectl describe pod worker-processor-7d9f-kp2l -n production
```

Ahmed skips straight to the container state section:

```
    State:          Waiting
      Reason:       CrashLoopBackOff
    Last State:     Terminated
      Reason:       OOMKilled
      Exit Code:    137
      Started:      Tue, 12 Mar 2024 09:14:22 +0000
      Finished:     Tue, 12 Mar 2024 09:14:58 +0000
```

Exit code **137**. That's the signature of an OOM kill. In Unix, signal 9 (SIGKILL) added to 128 = 137. The kernel sent SIGKILL with no warning, no graceful shutdown. The container simply ceased to exist.

The pod lived for exactly 36 seconds.

> **📚 Teaching moment — Exit code 137**
>
> Exit code 137 = 128 + 9 (SIGKILL). When a container's memory usage exceeds its `limit`, the Linux kernel OOM killer sends SIGKILL directly to the process. No warning, no graceful shutdown handler, no chance to flush buffers. The process is gone.
>
> This is fundamentally different from the app crashing on its own (which would produce an exit code from the app itself — like 1, or a panic exit code). Exit 137 means the *kernel* killed it, not the app.

---

## ACT II — The crime scene measurements

```bash
kubectl describe pod worker-processor-7d9f-kp2l -n production | grep -A 8 "Limits\|Requests"
```

```
    Limits:
      memory:  128Mi
    Requests:
      memory:  64Mi
```

128 MiB limit. Ahmed checks what the pod was actually trying to use.

```bash
kubectl top pod worker-processor-7d9f-kp2l -n production
```

```
Error from server (NotFound): pods "worker-processor-7d9f-kp2l" not found
```

The pod crashed again while he was typing. He checks historical metrics instead.

```bash
kubectl top pods -n production --sort-by=memory
```

The pod flickers back to life. For a moment:

```
NAME                         CPU(cores)   MEMORY(bytes)
worker-processor-7d9f-kp2l   342m         121Mi
```

121 MiB — already at 94% of its 128 MiB limit, and it's only been running for seconds. The pod is processing a queue of jobs and growing fast.

Ahmed checks the logs before the next crash:

```bash
kubectl logs worker-processor-7d9f-kp2l -n production -f
```

```
[INFO]  Processing batch job #4821 — 1200 records
[INFO]  Loading full dataset into memory for transformation...
[INFO]  Memory allocated: 118MB
[INFO]  Processing...
Killed
```

The application loads the entire dataset into memory. For small batches this was fine. But batch #4821 has 1200 records — more than the 128Mi limit can handle.

> **📚 Teaching moment — Limits vs Requests**
>
> - **Requests**: what Kubernetes *reserves* for the pod on the node. The scheduler uses this for placement.
> - **Limits**: the hard ceiling. If the container crosses this, the kernel kills it.
>
> Setting limits too low is as dangerous as not setting them at all. A container with no limit can eat all node memory and starve other pods. A container with a limit too low gets killed repeatedly.
>
> **The right approach:** observe real memory usage with `kubectl top` or Prometheus, then set limits at roughly 2x the observed peak, and set requests at the expected steady-state usage.

---

## ACT III — Two paths

Ahmed presents the team with two options.

**Option A — Quick fix:** Raise the memory limit.

```yaml
resources:
  requests:
    memory: "256Mi"
  limits:
    memory: "512Mi"
```

This buys time but doesn't fix the root cause. If batches keep growing, the pod will hit the new limit too.

**Option B — Proper fix:** Change the application to process records in chunks instead of loading everything into memory at once.

The team chooses Option A for now (production is down) and opens a ticket for Option B.

```bash
kubectl set resources deployment worker-processor \
  --limits=memory=512Mi \
  --requests=memory=256Mi \
  -n production
```

---

## ACT IV — The arrest

**Presenting problem:** Pod repeatedly killed with exit code 137 (`OOMKilled`).

**Root cause:** Memory limit of 128Mi was insufficient for the workload. Application loads full dataset batches into memory, and as batch sizes grew the container exceeded its limit.

```bash
kubectl get pods -n production
```

```
NAME                         READY   STATUS    RESTARTS   AGE
worker-processor-8e2a-mn4k   1/1     Running   0          2m
```

New ReplicaSet, new pod, running stable.

---

## EPILOGUE

*"Exit code 137 is not the application's fault. It's not Kubernetes's fault. It's a contract violation — the app promised to use 128 megabytes, then used more. The kernel enforced the contract. Next time, measure first. Set limits second."*

> **📚 Episode takeaways**
>
> | Signal | Meaning |
> |---|---|
> | Exit code 137 | OOMKilled — kernel sent SIGKILL due to memory limit exceeded |
> | `kubectl describe pod` → Last State | Shows exit code and reason for last crash |
> | `kubectl top pod` | Real-time memory/CPU usage |
> | `kubectl set resources` | Quick way to update limits without editing YAML |
>
> **Inspector Ahmed's Rule #4:** Exit code 137 means the kernel killed the container. Raise the limit as a quick fix — but always follow up with the root cause: why is the app using more memory than expected?
