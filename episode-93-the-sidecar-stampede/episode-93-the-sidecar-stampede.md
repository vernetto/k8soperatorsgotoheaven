# Episode 93 — "The Sidecar Stampede"
### *Inspector Ahmed and the logging agent that brings down the network*

**Culprit:** Log shipper sidecar not rate-limited — floods the network with log data
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `logging` `sidecar` `rate-limiting` `fluentbit` `network`

---

## OPENING — Crime scene

"Network throughput on the cluster had been climbing for two days. Not application traffic — monitoring showed it was all log traffic. A new logging sidecar had been deployed without any buffering or rate limiting."

```bash
kubectl top pods -n production --sort-by=cpu | head -10
```

```
NAME                          CPU(cores)   MEMORY(bytes)
api-7f9d4b-xk2p               180m         256Mi
api-7f9d4b-r8tn               175m         248Mi
...
```

Normal app CPUs. Ahmed checks network:

```bash
kubectl exec api-7f9d4b-xk2p -n production -c fluent-bit -- \
  cat /fluent-bit/etc/fluent-bit.conf | grep -A 5 "OUTPUT"
```

```
[OUTPUT]
    Name  es
    Host  elasticsearch.logging.svc
    Port  9200
    # No retry limit, no buffer limit, no rate limit
```

Fluent Bit with no limits. It's forwarding every log line immediately, at full speed. An application logging at debug level (100+ lines/second) × 20 pods = 2,000 log lines/second flooding Elasticsearch.

> **📚 Teaching moment — Log shipper configuration**
>
> Log shippers (Fluent Bit, Fluentd, Logstash) need guardrails:
> - **Buffer limits**: cap memory/disk used for buffering
> - **Flush interval**: batch log lines, don't send one at a time
> - **Retry limits**: don't retry failed sends indefinitely
> - **Input filters**: don't ship debug logs in production
>
> An unconfigured log shipper running alongside a verbose application can generate more network traffic than the application itself.

---

## ACT II — Adding rate limiting and batching

```ini
[OUTPUT]
    Name           es
    Host           elasticsearch.logging.svc
    Port           9200
    Buffer_Size    5MB
    Flush          5              # flush every 5 seconds
    Retry_Limit    3
    Workers        1

[FILTER]
    Name    grep
    Match   *
    Exclude log DEBUG            # don't ship debug lines
```

Also reduce the application's log level in production:

```bash
kubectl set env deployment/api LOG_LEVEL=warn -n production
```

Network traffic drops 95%.

---

## EPILOGUE

*"A log shipper with no limits is a network firehose. Always configure buffer limits, flush intervals, and log level filters. Never ship DEBUG logs from production to a centralised store. The logs cost more than the insights they provide."*

> **Inspector Ahmed's Rule #93:** Cluster network flooded with log traffic? Check log sidecar configuration for missing rate limits and buffer caps. Add flush intervals. Filter debug logs in production. Logs should follow the app — not overwhelm the network.
