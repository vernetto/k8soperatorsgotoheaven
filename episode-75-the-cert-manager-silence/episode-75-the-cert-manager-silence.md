# Episode 75 — "The Cert-Manager Silence"
### *Inspector Ahmed and the certificate that is issued but never used*

**Culprit:** cert-manager issues the certificate into the wrong Secret name — Ingress TLS references a different Secret
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `cert-manager` `tls` `ingress` `certificates` `secrets`

---

## OPENING — Crime scene

"cert-manager was installed. The Certificate resource showed `Ready: True`. But the browser still showed an expired certificate. The new cert had been issued — and gone to the wrong place."

```bash
kubectl get certificate -n production
```

```
NAME        READY   SECRET          AGE
api-cert    True    api-tls-new     2m
```

Certificate issued and `Ready`. Ahmed checks the Ingress:

```bash
kubectl get ingress api-ingress -n production -o yaml | grep -A 5 "tls:"
```

```yaml
tls:
- hosts:
  - api.example.com
  secretName: api-tls     ← references api-tls
```

The Ingress uses `api-tls`. The certificate was issued into `api-tls-new`. Different names. The Ingress controller is still serving the old (expired) certificate from `api-tls`.

---

## ACT I — The mismatch

```bash
kubectl get secret api-tls -n production
kubectl get secret api-tls-new -n production
```

```
NAME          TYPE                DATA   AGE
api-tls       kubernetes.io/tls   2      365d    ← old, expired
api-tls-new   kubernetes.io/tls   2      2m      ← new, valid
```

The Certificate resource was created with `secretName: api-tls-new` but the Ingress still references `api-tls`. Ahmed checks the Certificate spec:

```bash
kubectl get certificate api-cert -n production -o yaml | grep secretName
```

```
  secretName: api-tls-new
```

Mismatch. Either the Ingress was created pointing to `api-tls`, or the Certificate was created with the wrong `secretName`.

> **📚 Teaching moment — cert-manager + Ingress integration**
>
> Two ways to use cert-manager with Ingress:
>
> **Method 1 — Ingress annotation** (cert-manager manages the cert automatically):
> ```yaml
> annotations:
>   cert-manager.io/cluster-issuer: letsencrypt-prod
> spec:
>   tls:
>   - hosts: [api.example.com]
>     secretName: api-tls    # cert-manager creates this Secret
> ```
>
> **Method 2 — Explicit Certificate resource**:
> ```yaml
> spec:
>   secretName: api-tls    # MUST match Ingress tls.secretName
> ```
>
> In both cases: the Certificate's `secretName` must exactly match the Ingress `tls.secretName`.

---

## ACT II — The fix

**Option A — Update the Certificate to write into the correct Secret:**

```bash
kubectl patch certificate api-cert -n production \
  --type=merge \
  -p '{"spec":{"secretName":"api-tls"}}'
```

cert-manager re-issues the certificate into `api-tls`. The Ingress controller picks it up within seconds.

**Option B — Update the Ingress to reference the new Secret:**

```bash
kubectl patch ingress api-ingress -n production \
  --type=json \
  -p='[{"op":"replace","path":"/spec/tls/0/secretName","value":"api-tls-new"}]'
```

---

## EPILOGUE

*"cert-manager issues the certificate into whatever Secret name you tell it. If that name doesn't match what the Ingress is looking for, the new cert is never served. The Certificate can be Ready while the Ingress serves an expired cert. Always verify the secretName matches."*

> **Inspector Ahmed's Rule #75:** cert-manager Certificate Ready but browser shows old/expired cert? Check that `certificate.spec.secretName` matches `ingress.spec.tls.secretName`. They must be identical.
