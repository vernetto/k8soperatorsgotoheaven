# Episode 64 — "The Exhausted Job"
### *Inspector Ahmed and the batch job that silently gives up*

**Culprit:** Job backoffLimit exhausted — job marked Failed with no alert
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `jobs` `backofflimit` `failure` `monitoring` `batch`

---

## OPENING — Crime scene

"The nightly ETL job was marked Complete in the dashboard. But the database was missing two days of data. The job had failed — exhausted its retry budget — and Kubernetes had recorded it as Failed. The dashboard was looking at the wrong field."

```bash
kubectl get jobs -n batch | grep etl
```

```
NAME                     COMPLETIONS   DURATION   AGE
etl-nightly-20240313     0/1           47m        47m
etl-nightly-20240312     0/1           38m        2d
```

`0/1` — neither completed successfully.

```bash
kubectl describe job etl-nightly-20240313 -n batch
```

```
Status:
  Failed: 4
  Conditions:
  - type: Failed
    status: "True"
    reason: BackoffLimitExceeded
    message: Job has reached the specified backoff limit
```

`BackoffLimitExceeded`. The job retried 4 times (the default `backoffLimit`), all failed, and was marked Failed. No alert fired.

---

## ACT I — Reading the failure

```bash
kubectl get pods -n batch -l job-name=etl-nightly-20240313
```

```
NAME                         READY   STATUS   RESTARTS   AGE
etl-nightly-20240313-xk2p    0/1     Error    0          47m
etl-nightly-20240313-r8tn    0/1     Error    0          40m
etl-nightly-20240313-9lmw    0/1     Error    0          35m
etl-nightly-20240313-mn2x    0/1     Error    0          30m
```

Four pods, all errored. Ahmed reads logs from the last one:

```bash
kubectl logs etl-nightly-20240313-mn2x -n batch
```

```
[ERROR] Failed to connect to data source: connection refused
[ERROR] Host: legacy-data-api.internal:8080
[ERROR] The legacy API service appears to be offline.
```

The upstream data source is down. The ETL job can't connect. It retried 4 times and gave up.

> **📚 Teaching moment — Job backoffLimit and monitoring**
>
> A Job's `backoffLimit` (default: 6) controls how many times the pod can fail before the Job is marked Failed. When `BackoffLimitExceeded`, no more retries happen.
>
> Failed Jobs don't disappear — they remain as records. But without monitoring, nobody knows.
>
> Essential monitoring:
> - Alert on `kube_job_status_failed > 0`
> - Or use Prometheus: `kube_job_failed`
> - Consider `activeDeadlineSeconds` to prevent a job from running indefinitely

---

## ACT II — Fix and alert

Fix the upstream service. Then re-trigger the job:

```bash
# Delete the failed job
kubectl delete job etl-nightly-20240313 -n batch

# Create a new run
kubectl create job etl-manual-recover --from=cronjob/etl-nightly -n batch
```

Add a Prometheus alert:

```yaml
- alert: KubernetesJobFailed
  expr: kube_job_status_failed > 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "Kubernetes Job {{ $labels.job_name }} failed"
```

---

## EPILOGUE

*"A failed Job is silent unless you're watching. backoffLimit exhaustion means the job gave up after retrying. Always alert on kube_job_status_failed. A batch pipeline that fails without notification is not a pipeline — it's a gamble."*

> **Inspector Ahmed's Rule #64:** Jobs can fail silently. `kubectl get jobs | grep 0/1` shows failed ones. Alert on `kube_job_status_failed`. Check logs of the last pod to understand why. Fix the root cause before re-running.
