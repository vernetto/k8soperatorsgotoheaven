# Episode 92 — "The Graceful Death That Wasn't"
### *Inspector Ahmed and the job that left data half-written*

**Culprit:** Job pod not handling SIGTERM — data pipeline terminates mid-write, producing corrupt output
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `sigterm` `graceful-shutdown` `jobs` `data-integrity` `preStop`

---

## OPENING — Crime scene

"The ETL job was interrupted by a node drain. The pod received SIGTERM. The job exited immediately — mid-transaction. The output database had half-written records. Data integrity was violated."

```bash
kubectl logs etl-job-7f9d4b-xk2p -n batch
```

```
[INFO]  Processing batch 47/100...
[INFO]  Writing 500 records to output database...
[INFO]  Written: 234/500
Killed
```

234 out of 500 records written. Then killed. The application received SIGTERM (which on most Node.js apps causes immediate exit) while in the middle of a write.

---

## ACT I — The shutdown handler

The application was not handling SIGTERM gracefully. It exited immediately when the signal arrived.

> **📚 Teaching moment — Graceful shutdown for batch jobs**
>
> Interactive services need graceful shutdown to drain in-flight requests. Batch jobs need graceful shutdown to:
> - Complete the current record/batch before exiting
> - Flush write buffers
> - Commit or rollback open transactions
> - Checkpoint progress so a restart can resume from a known-good state
>
> The `terminationGracePeriodSeconds` default is 30s — enough time to finish a small batch. For long-running records, increase it. The application must handle SIGTERM and stop accepting new work while finishing current work.

---

## ACT II — Adding a SIGTERM handler

```javascript
let shuttingDown = false;

process.on('SIGTERM', () => {
  console.log('[INFO] Received SIGTERM — finishing current batch before exit...');
  shuttingDown = true;
});

async function processBatches() {
  for (const batch of batches) {
    if (shuttingDown) {
      console.log('[INFO] Graceful shutdown: checkpointing progress...');
      await checkpointProgress(currentBatchIndex);
      process.exit(0);
    }
    await processBatch(batch);
    await commitTransaction();
  }
}
```

Also increase the grace period:

```yaml
terminationGracePeriodSeconds: 120   # allow up to 2 min to finish current batch
```

---

## EPILOGUE

*"Batch jobs must handle SIGTERM gracefully. Set a flag, finish the current unit of work, commit or checkpoint, then exit cleanly. Increase terminationGracePeriodSeconds to give enough time. Never let a batch job die mid-transaction."*

> **Inspector Ahmed's Rule #92:** Batch job producing corrupt/incomplete output after node drain? It's not handling SIGTERM. Add a signal handler that finishes current work before exiting. Increase terminationGracePeriodSeconds to cover the longest expected batch.
