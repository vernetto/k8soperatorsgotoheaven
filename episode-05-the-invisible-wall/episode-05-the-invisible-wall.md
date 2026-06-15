# Episode 5 — "The Invisible Wall"
### *Inspector Ahmed and the service that goes nowhere*

**Culprit:** NetworkPolicy blocking inter-pod communication
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `networkpolicy` `networking` `connectivity` `dns`

---

## OPENING — Crime scene

"The pods were running. The service existed. The endpoints were populated. And yet the frontend couldn't reach the backend. Traffic was vanishing into thin air — stopped by something invisible."

```bash
kubectl get pods -n production
```

```
NAME                        READY   STATUS    RESTARTS   AGE
frontend-6d8f9-xk2p         1/1     Running   0          20m
backend-api-7f9d4-r8tn      1/1     Running   0          20m
```

Both running. Ahmed checks the service and endpoints.

```bash
kubectl get svc,endpoints -n production
```

```
NAME                    TYPE        CLUSTER-IP      PORT(S)    AGE
service/backend-api     ClusterIP   10.96.144.22    8080/TCP   20m

NAME                      ENDPOINTS          AGE
endpoints/backend-api     10.244.2.14:8080   20m
```

Endpoint exists. The service is correctly pointing to the backend pod. Ahmed tries a direct curl from inside the frontend pod.

```bash
kubectl exec -it frontend-6d8f9-xk2p -n production -- \
  curl -v http://backend-api:8080/health --max-time 5
```

```
* Trying 10.96.144.22:80...
* Connection timed out after 5001 milliseconds
* Closing connection 0
curl: (28) Connection timed out after 5001 milliseconds
```

Not refused — *timed out*. Refused means the port is closed. Timed out means something is dropping the packets silently.

> **📚 Teaching moment — Timeout vs Connection Refused**
>
> - **Connection refused**: the destination is reachable but nothing is listening on that port. Fast failure.
> - **Connection timed out**: packets are being sent but nothing responds. This points to a firewall, a NetworkPolicy, or a routing issue dropping packets silently.
>
> In Kubernetes, silent packet drops are almost always NetworkPolicy.

---

## ACT I — Finding the wall

```bash
kubectl get networkpolicy -n production
```

```
NAME                    POD-SELECTOR        AGE
deny-all-ingress        <none>              5d
allow-frontend-to-db    app=database        5d
```

A `deny-all-ingress` policy. Someone applied a default-deny policy 5 days ago as a security hardening measure — and forgot to add an explicit allow rule for frontend→backend traffic.

```bash
kubectl describe networkpolicy deny-all-ingress -n production
```

```
Spec:
  PodSelector:     <none> (Selecting all pods)
  Allowing ingress traffic:
    <none> (Selected pods are isolated for ingress connectivity)
  Not affecting egress traffic
  Policy Types: Ingress
```

This policy selects *all pods* in the namespace and allows *no ingress* — effectively blocking all incoming traffic to every pod. The backend is unreachable because no ingress is permitted to it.

---

## ACT II — Writing the allow rule

Ahmed creates a NetworkPolicy that explicitly allows the frontend to reach the backend:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend-api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
EOF
```

```bash
kubectl exec -it frontend-6d8f9-xk2p -n production -- \
  curl -s http://backend-api:8080/health
```

```
{"status":"ok","version":"2.4.1"}
```

Traffic flows.

---

## EPILOGUE

*"NetworkPolicy is additive — you add rules to allow, not to block. A deny-all policy is like a locked building. You don't unlock the building. You give people keys to specific doors."*

> **📚 Episode takeaways**
>
> | Signal | Meaning |
> |---|---|
> | Connection timeout (not refused) | Packet drop — suspect NetworkPolicy |
> | `kubectl get networkpolicy -n <ns>` | List all policies in the namespace |
> | `deny-all` with no matching allow | Traffic silently blocked |
>
> **Inspector Ahmed's Rule #5:** A timeout between healthy pods almost always means NetworkPolicy. Always check for a `deny-all` policy first.
