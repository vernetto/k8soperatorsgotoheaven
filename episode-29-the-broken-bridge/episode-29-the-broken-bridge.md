# Episode 29 — "The Broken Bridge"
### *Inspector Ahmed and the Ingress that returns 404 for everything*

**Culprit:** Ingress controller not installed — Ingress resources are ignored
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `ingress` `ingress-controller` `nginx` `traefik` `404`

---

## OPENING — Crime scene

"The Ingress was created. The rules were correct. The backend pods were running. But every HTTP request to the cluster returned 404. Not 502, not 503 — 404. As if nothing existed."

```bash
kubectl get ingress -n production
```

```
NAME          CLASS    HOSTS                ADDRESS   PORTS   AGE
api-ingress   nginx    api.example.com                80      10m
```

No ADDRESS. The Ingress has been created but never received an IP. That's the first clue.

> **📚 Teaching moment — Ingress is just a spec**
>
> An Ingress resource is just a configuration object — it describes routing rules. By itself it does nothing. You need an **Ingress Controller** — a pod that watches Ingress resources and actually implements the routing (by configuring nginx, Traefik, HAProxy, Envoy, etc.).
>
> An Ingress with no controller is like a road sign with no road. The rules are written — but nothing enforces them.

---

## ACT I — No controller

```bash
kubectl get pods -n ingress-nginx
```

```
Error from server (NotFound): namespaces "ingress-nginx" not found
```

```bash
kubectl get pods --all-namespaces | grep ingress
```

```
(no output)
```

No ingress controller anywhere in the cluster.

---

## ACT II — Installing nginx ingress controller

```bash
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

```bash
kubectl get pods -n ingress-nginx
```

```
NAME                                        READY   STATUS    RESTARTS   AGE
ingress-nginx-controller-7f9d4b-xk2p        1/1     Running   0          30s
```

```bash
kubectl get ingress -n production
```

```
NAME          CLASS    HOSTS              ADDRESS          PORTS   AGE
api-ingress   nginx    api.example.com    203.0.113.42     80      15m
```

ADDRESS populated. Traffic flows.

---

## EPILOGUE

*"An Ingress with no address means no controller is watching it. The spec exists but nothing reads it. Always verify your ingress controller is running before debugging routing rules."*

> **Inspector Ahmed's Rule #29:** Ingress with no ADDRESS = no ingress controller. Install one. Then the Ingress rules take effect.
