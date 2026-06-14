# Episode 81 — "The Sleeping Cron"
### *Inspector Ahmed and the CronJob that misses its schedule*

**Culprit:** CronJob startingDeadlineSeconds too short — job missed its window and was skipped
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `cronjob` `startingdeadline` `scheduling` `missed-schedule`

---

## OPENING — Crime scene

"The daily report CronJob was scheduled for 2:00am. By 2:01am it should have run. Ahmed checked at 9am — it hadn't run. No errors. No failures. Just silence. The job had been skipped."

```bash
kubectl get cronjob daily-report -n batch
```

```
NAME           SCHEDULE    SUSPEND   ACTIVE   LAST SCHEDULE   AGE
daily-report   0 2 * * *   False     0        <none>          30d
```

`LAST SCHEDULE: <none>`. The job has never run successfully — or its record was lost.

```bash
kubectl describe cronjob daily-report -n batch
```

```
Events:
  Warning  MissSchedule  7h  cronjob-controller
    Cannot determine if job needs to be started:
    too many missed start times (> 100).
    Set or decrease .spec.startingDeadlineSeconds to ensure
    the job is not skipped.
```

`Too many missed start times (> 100)`. The CronJob controller gave up.

---

## ACT I — Understanding the deadline

The CronJob controller was restarted (due to a control plane maintenance) and was offline from midnight to 6am. When it came back, it tried to calculate how many schedule intervals it had missed. If the controller has been offline for longer than `startingDeadlineSeconds` (or if there are more than 100 missed schedules to consider), it skips all missed runs and resets.

```bash
kubectl get cronjob daily-report -n batch -o yaml | grep startingDeadline
```

```
(no output)
```

No `startingDeadlineSeconds` set — the default is no deadline, which makes the controller look back indefinitely, find > 100 missed windows, and refuse to run.

> **📚 Teaching moment — startingDeadlineSeconds**
>
> `startingDeadlineSeconds` defines the deadline (in seconds) within which a missed job must start — or it's skipped.
>
> If `startingDeadlineSeconds: 3600` (1 hour) and the scheduler was down for 6 hours, the job is skipped for those 6 hours and only runs at the next scheduled time.
>
> **The 100-missed-schedules rule**: When the controller restarts, it looks at the last `startingDeadlineSeconds` window to determine how many schedules were missed. If there's no `startingDeadlineSeconds` and the controller was offline, it looks back across all time — potentially finding hundreds of missed windows — and declares "too many missed starts."
>
> **Fix**: always set `startingDeadlineSeconds` to a reasonable value (e.g., 3600 = 1 hour for hourly jobs, 86400 = 1 day for daily jobs).

---

## ACT II — The fix

```yaml
spec:
  schedule: "0 2 * * *"
  startingDeadlineSeconds: 3600   # must start within 1 hour of scheduled time
  concurrencyPolicy: Forbid
  jobTemplate:
    ...
```

Then manually trigger the missed run:

```bash
kubectl create job daily-report-manual --from=cronjob/daily-report -n batch
```

---

## EPILOGUE

*"A CronJob with no startingDeadlineSeconds and a controller restart is a recipe for a silent skip. Always set startingDeadlineSeconds. If the controller was down, manually trigger the missed job."*

> **Inspector Ahmed's Rule #81:** CronJob never ran and shows 'too many missed start times'? The controller restarted and found > 100 missed windows. Set `startingDeadlineSeconds`. Manually trigger the missed run with `kubectl create job --from=cronjob/...`.
