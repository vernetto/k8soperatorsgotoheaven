# Episode 26 — "The Phantom Port"
### *Inspector Ahmed and the service that targets the wrong port*

**Culprit:** Service `targetPort` doesn't match the port the container actually listens on
**Difficulty:** ⭐ Beginner
**Tags:** `service` `ports` `targetport` `containerport`

---

## OPENING — Crime scene

"The service existed. The endpoints were populated. The pod was running. And every single request to the service returned `Connection refused`. Not timeout — refused. Something was listening, but not where the service was looking."

```bash
kubectl get endpoints api-service -n production
```

```
NAME          ENDPOINTS            AGE
api-service   10.244.2.14:3000     10m
```

Endpoint exists. Ahmed connects directly to the pod IP:

```bash
kubectl exec -it debug-pod -n production -- \
  curl http://10.244.2.14:3000 --max-time 3
```

```
curl: (7) Failed to connect to 10.244.2.14 port 3000: Connection refused
```

Port 3000 is refusing connections. Ahmed checks what the container is actually listening on:

```bash
kubectl exec api-7f9d4b-xk2p -n production -- ss -tlnp
```

```
State    Recv-Q   Send-Q   Local Address:Port
LISTEN   0        128      0.0.0.0:8080
```

Port **8080**. The container listens on 8080. The service is sending traffic to 3000.

> **📚 Teaching moment — Service port terminology**
>
> A Service has three port fields:
> - **port**: the port exposed by the Service (what clients use)
> - **targetPort**: the port on the *pod* where traffic is forwarded
> - **containerPort** (in pod spec): documentation only — Kubernetes doesn't use it for routing
>
> `targetPort` must match what the container actually listens on. `containerPort` is just metadata.

---

## ACT II — The fix

```bash
kubectl patch svc api-service -n production \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/ports/0/targetPort","value":8080}]'
```

```bash
curl http://10.244.2.14:8080
```

```
{"status":"ok"}
```

---

## EPILOGUE

*"containerPort in the pod spec is a comment. It doesn't route traffic. The Service's targetPort does. And it must match what the app actually listens on — not what someone wrote in the manifest."*

> **Inspector Ahmed's Rule #26:** Connection refused on a healthy pod = wrong targetPort. Check `ss -tlnp` inside the container. Fix the Service `targetPort` to match.
