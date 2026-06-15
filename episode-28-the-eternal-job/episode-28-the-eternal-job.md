# Episode 28 — "The Eternal Job"
### *Inspector Ahmed and the CronJob that fires twice*

**Culprit:** CronJob with no concurrency policy — overlapping executions pile up
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `cronjob` `jobs` `concurrency` `scheduling`

---

## OPENING — Crime scene

"The billing job was supposed to run once a day at 2am. The database showed billing records generated three times for some customers. The job had run three times — all at the same time."

```bash
kubectl get cronjob billing-job -n production
```

```
NAME          SCHEDULE    SUSPEND   ACTIVE   LAST SCHEDULE   AGE
billing-job   0 2 * * *   False     3        2h              90d
```

**ACTIVE: 3**. Three concurrent executions of the same job.

---

## ACT I — The concurrency problem

```bash
kubectl get jobs -n production | grep billing
```

```
NAME                       COMPLETIONS   DURATION   AGE
billing-job-28498800        0/1           58m        58m
billing-job-28498740        0/1           118m       118m
billing-job-28498680        1/1           3h         178m
```

Three job runs. The first completed. The next two are still running — each 60 minutes apart. The CronJob fired multiple times, and without a concurrency policy, all executions pile up.

> **📚 Teaching moment — CronJob concurrencyPolicy**
>
> CronJob has three concurrency policies:
> - **Allow** (default): multiple jobs can run concurrently. Fine for short jobs; dangerous for long ones.
> - **Forbid**: if the previous job is still running, skip the new one
> - **Replace**: if the previous job is still running, cancel it and start a new one
>
> For billing, database maintenance, or any job that must not run concurrently: use `Forbid`.
> For jobs that must always run the latest version: use `Replace`.

---

## ACT II — The fix

```yaml
spec:
  concurrencyPolicy: Forbid
  startingDeadlineSeconds: 300  # if job can't start within 5 min of scheduled time, skip it
```

Clean up the duplicate jobs:

```bash
kubectl delete job billing-job-28498800 billing-job-28498740 -n production
```

---

## EPILOGUE

*"The default CronJob concurrency policy is Allow. For any job that touches data, processes payments, or must not run twice: set it to Forbid. The default will bite you eventually."*

> **Inspector Ahmed's Rule #28:** CronJob with ACTIVE > 1 = no concurrency policy set. For data-critical jobs, always use `concurrencyPolicy: Forbid`.
