# Episode 68 — "The KEDA Ghost"
### *Inspector Ahmed and the scaler with a dead event source*

**Culprit:** KEDA ScaledObject pointing to a deleted queue — workload scales to 0 despite pending work
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `keda` `event-driven` `autoscaling` `queue` `rabbitmq`

---

## OPENING — Crime scene

"The message queue was full. 40,000 unprocessed messages. The worker deployment was at 0 replicas. KEDA was supposed to scale it up based on queue depth. But the worker hadn't started in two hours."

```bash
kubectl get scaledobject -n workers
```

```
NAME             SCALETARGETKIND   SCALETARGETNAME   READY   REASON
queue-worker     Deployment        message-worker    False   External scaler is not available
```

`READY: False`. The ScaledObject is broken.

---

## ACT I — The dead trigger

```bash
kubectl describe scaledobject queue-worker -n workers
```

```
Events:
  Warning  KEDAScalerFailed  2m  keda-operator
    error resolving scaler for ScaledObject:
    error when connecting to trigger source:
    Exception occurred: RabbitMQ broker "rabbitmq.messaging.svc:5672"
    is not reachable
```

KEDA can't connect to RabbitMQ. It was migrated to a new namespace and the connection string in the ScaledObject wasn't updated.

```bash
kubectl get svc -n messaging | grep rabbit
```

```
rabbitmq-headless   ClusterIP   None   5672/TCP   30d
rabbitmq            ClusterIP   10.96.77.22   5672/TCP   30d
```

The service is in namespace `messaging`. The ScaledObject references `rabbitmq.messaging.svc:5672` — but uses an old host name format. The correct FQDN is `rabbitmq.messaging.svc.cluster.local`.

> **📚 Teaching moment — KEDA ScaledObject and fallback**
>
> KEDA extends the HPA concept to event-driven sources (queues, topics, databases, cron schedules). When the trigger source is unreachable, KEDA can't get metrics — and defaults to 0 replicas.
>
> KEDA supports a `fallback` configuration:
> ```yaml
> fallback:
>   failureThreshold: 3
>   replicas: 2    # minimum replicas when scaler fails
> ```
> With fallback configured, if the scaler fails 3 consecutive times, KEDA uses 2 replicas instead of 0. This prevents workers from scaling to 0 when the metrics source is temporarily unavailable.

---

## ACT II — Fix the connection

```bash
kubectl patch scaledobject queue-worker -n workers \
  --type=merge \
  -p '{
    "spec": {
      "triggers": [{
        "type": "rabbitmq",
        "metadata": {
          "host": "rabbitmq.messaging.svc.cluster.local:5672",
          "queueName": "work-queue"
        }
      }],
      "fallback": {
        "failureThreshold": 3,
        "replicas": 2
      }
    }
  }'
```

```bash
kubectl get scaledobject queue-worker -n workers
```

```
NAME           READY   REASON                  REPLICAS
queue-worker   True    ScalerReady             12
```

KEDA reads 40,000 messages in the queue and scales to 12 workers.

---

## EPILOGUE

*"KEDA scaling to zero when the queue is full means the scaler can't read the queue — not that the queue is empty. Check ScaledObject READY status. Fix the trigger source connection. Always configure fallback replicas to prevent accidental scale-to-zero."*

> **Inspector Ahmed's Rule #68:** KEDA ScaledObject READY=False? `kubectl describe scaledobject` shows the connection error. Fix the trigger source URL. Add fallback replicas to prevent scale-to-zero when metrics are unavailable.
