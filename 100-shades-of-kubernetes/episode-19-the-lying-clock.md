# Episode 19 — "The Lying Clock"
### *Inspector Ahmed and the TLS certificate that expired at the worst moment*

**Culprit:** Expired TLS certificate in a Secret — HTTPS connections rejected
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `tls` `certificates` `ingress` `secrets` `cert-manager`

---

## OPENING — Crime scene

"The application had been running fine for eleven months. On a random Tuesday morning, every HTTPS request started returning `ERR_CERT_DATE_INVALID`. The certificate had silently expired overnight."

```bash
kubectl describe ingress api-ingress -n production
```

```
TLS:
  api-tls terminates api.example.com
```

```bash
kubectl get secret api-tls -n production -o yaml | grep tls.crt | \
  awk '{print $2}' | base64 -d | openssl x509 -noout -dates
```

```
notBefore=Mar 14 00:00:00 2023 GMT
notAfter=Mar 14 23:59:59 2024 GMT
```

Expired yesterday. A certificate that was never set up for automatic renewal.

> **📚 Teaching moment — TLS Secrets in Kubernetes**
>
> Kubernetes stores TLS certificates as Secrets of type `kubernetes.io/tls` with two keys: `tls.crt` (the certificate) and `tls.key` (the private key).
>
> These Secrets don't renew themselves. If you manually created the Secret, you're responsible for renewing it before it expires.
>
> The solution is **cert-manager** — a Kubernetes operator that automatically provisions and renews certificates from Let's Encrypt, Vault, or other CAs. Once installed, you annotate your Ingress and cert-manager handles the rest, renewing certificates 30 days before expiry.

---

## ACT II — Emergency renewal

```bash
# Generate new self-signed cert (emergency only — not for production)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=api.example.com/O=MyCompany"

kubectl create secret tls api-tls \
  --cert=tls.crt --key=tls.key \
  -n production --dry-run=client -o yaml | kubectl apply -f -
```

For a real certificate, use cert-manager:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: api-tls
  namespace: production
spec:
  secretName: api-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - api.example.com
```

---

## EPILOGUE

*"A certificate that expires on a Tuesday morning at 3am is not bad luck. It's the inevitable result of not automating renewal. Install cert-manager. Never think about certificate expiry again."*

> **Inspector Ahmed's Rule #19:** TLS errors? Check certificate expiry first. `openssl x509 -noout -dates` on the Secret. Then install cert-manager so this never happens again.
