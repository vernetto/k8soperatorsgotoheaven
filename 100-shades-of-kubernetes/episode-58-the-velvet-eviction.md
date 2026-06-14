# Episode 58 — "The Velvet Eviction"
### *Inspector Ahmed and the backup that silently fails*

**Culprit:** Velero backup failing silently — no alerts configured on backup status
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `velero` `backup` `disaster-recovery` `monitoring`

---

## OPENING — Crime scene

"The cluster had been 'backed up' for six months. Until the day they needed a restore — and discovered that every backup for the last two months had silently failed. The schedule ran. The CRD existed. The backups did not."

```bash
kubectl get backup -n velero | tail -10
```

```
NAME                          STATUS    STARTED   COMPLETED   ERRORS   WARNINGS
daily-backup-20240312         Failed    2h ago    2h ago      3        0
daily-backup-20240311         Failed    26h ago   26h ago     3        0
daily-backup-20240310         Failed    50h ago   50h ago     3        0
daily-backup-20240309         Failed    74h ago   74h ago     3        0
```

Every backup for the last two months: Failed. With no alert configured on backup status, nobody noticed.

---

## ACT I — Reading the failure

```bash
kubectl describe backup daily-backup-20240312 -n velero
```

```
Status:
  Phase: Failed
  Errors:
    Velero:
    - error getting backup store: rpc error: code = Unknown
      desc = AccessDenied: Access Denied
      status code: 403
      request id: ABC123
      StorageClass: s3://company-velero-backups
```

403 Access Denied to S3. The IAM role used by Velero lost its S3 permissions two months ago — likely during an IAM policy cleanup that removed the Velero policy by mistake.

> **📚 Teaching moment — Monitoring Velero backups**
>
> Velero records backup results as Kubernetes Custom Resources. Without monitoring these CRs, failures are invisible.
>
> Essential monitoring:
> - Alert when `backup.status.phase == Failed`
> - Alert when no backup has succeeded in the last 25 hours
> - Use Velero's Prometheus metrics: `velero_backup_success_total`, `velero_backup_failure_total`
> - Set `--backup-ttl` to control how long backup objects are retained
>
> A backup solution with no alerts on failure is not a backup solution — it's a false sense of security.

---

## ACT II — Restoring IAM and verifying

```bash
# Attach the correct S3 policy to the Velero IAM role
aws iam attach-role-policy \
  --role-name velero-backup-role \
  --policy-arn arn:aws:iam::123456789:policy/VeleroBackupPolicy

# Trigger a manual backup to verify
velero backup create manual-verify-backup --wait
```

```
Backup completed with status: Completed. You may check for '--wait' completion details.
```

Set up alerting via Prometheus:

```yaml
- alert: VeleroBackupFailed
  expr: velero_backup_failure_total > 0
  for: 5m
  annotations:
    summary: "Velero backup has failed"
```

---

## EPILOGUE

*"A backup that fails silently is worse than no backup — it gives false confidence. Every backup system must have alerts on failure. Check your Velero backup status right now. Not tomorrow."*

> **Inspector Ahmed's Rule #58:** Trust but verify backups. `kubectl get backup -n velero` should show only Completed, never Failed. Alert on failures. A failed backup discovered during a disaster is not a backup.
