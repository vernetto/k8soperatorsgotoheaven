# Episode 34 — "The Leaking Pipe"
### *Inspector Ahmed and the connection pool that never closes*

**Culprit:** Database connection leak — pods accumulate open connections until DB refuses new ones
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `connections` `postgresql` `leaks` `debugging` `ephemeral-containers`

---

## OPENING — Crime scene

"The database started rejecting connections. 'Too many clients' — the error message was clear. But nobody had deployed anything new. The connection count had been climbing for three days, slowly, like a leak in a tank."

```bash
kubectl exec postgres-0 -n database -- \
  psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"
```

```
 count
-------
   497
(1 row)
```

PostgreSQL's `max_connections` was set to 500. 497 connections open. The database was two connections from refusing everything.

---

## ACT I — Finding the leak

```bash
kubectl exec postgres-0 -n database -- \
  psql -U postgres -c "
  SELECT client_addr, count(*), state
  FROM pg_stat_activity
  GROUP BY client_addr, state
  ORDER BY count DESC;"
```

```
  client_addr    | count |  state
-----------------+-------+----------
 10.244.1.23     |   120 | idle
 10.244.2.45     |   118 | idle
 10.244.3.12     |   115 | idle
```

Three pod IPs, each holding 115-120 idle connections. These are the api-server pods. They're connected — but doing nothing. Classic connection leak: connections opened but never returned to the pool or closed.

```bash
kubectl exec api-7f9d4b-xk2p -n production -- \
  cat /proc/net/tcp | wc -l
```

Ahmed uses an ephemeral debug container to investigate the running process without restarting it:

```bash
kubectl debug -it api-7f9d4b-xk2p -n production \
  --image=nicolaka/netshoot \
  --target=api -- bash
```

```bash
# Inside debug container
ss -tn | grep 5432 | wc -l
```

```
120
```

120 open connections to port 5432 from this single pod.

> **📚 Teaching moment — Ephemeral containers**
>
> `kubectl debug` injects a temporary debug container into a running pod without restarting it. The debug container shares the pod's network namespace, so you can inspect connections, run tcpdump, or use tools not present in the original image.
>
> This is essential for debugging production issues without disrupting the running application.

---

## ACT II — The fix

The application was using a connection pool but had a code path that opened direct connections outside the pool for "background tasks" — and never closed them.

Short-term fix: restart the pods to flush connections, and set `max_connections` guard in the pool:

```javascript
// Add pool limits
const pool = new Pool({
  max: 10,           // max 10 connections per pod
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

Long-term: use PgBouncer as a connection pooler in front of PostgreSQL to limit and manage connections cluster-wide.

---

## EPILOGUE

*"A connection leak is silent for days. Then it kills the database in minutes. Watch `pg_stat_activity` counts over time. If idle connections keep growing, you have a leak. Use ephemeral debug containers to investigate without restarting."*

> **Inspector Ahmed's Rule #34:** DB 'too many connections' with no traffic spike = connection leak. Use `kubectl debug` with a netshoot container to inspect connections without restarting the pod.
