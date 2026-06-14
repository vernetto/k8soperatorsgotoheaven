# Episode 84 — "The Certificate Authority Chain"
### *Inspector Ahmed and the custom CA that nobody trusted*

**Culprit:** Webhook service using a self-signed certificate — cluster components can't verify it
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `tls` `certificates` `webhook` `ca` `trust`

---

## OPENING — Crime scene

"A new internal webhook service was deployed. Its TLS was configured. But every API server call that triggered the webhook returned a certificate verification failure. The certificate was valid — the cluster just didn't trust the CA that signed it."

```bash
kubectl apply -f deployment.yaml
```

```
Error from server (InternalError): Internal error occurred:
  failed calling webhook "validate.internal.company.com":
  Post "https://internal-validator.webhooks.svc:8443/validate":
  x509: certificate signed by unknown authority
```

`certificate signed by unknown authority`. The webhook uses a certificate signed by an internal CA that is not in the API server's trust store.

---

## ACT I — The caBundle

In a `ValidatingWebhookConfiguration`, each webhook has a `caBundle` field — the CA certificate that the API server uses to verify the webhook's TLS certificate.

```bash
kubectl get validatingwebhookconfiguration internal-validator \
  -o yaml | grep caBundle
```

```
caBundle: ""
```

Empty. No CA bundle configured. The API server has no CA to verify the webhook's certificate against, so it fails.

> **📚 Teaching moment — Webhook TLS verification**
>
> The API server calls webhooks over HTTPS. It verifies the webhook server's certificate using the `caBundle` in the webhook configuration. This must be the PEM-encoded CA certificate (or chain) that signed the webhook's TLS certificate.
>
> Options:
> 1. **Provide the CA in caBundle**: base64-encode the CA cert and put it in the field
> 2. **Use cert-manager with CA injector**: cert-manager automatically injects the CA bundle when you annotate the webhook configuration
> 3. **Use a public CA**: if the webhook cert is signed by a public CA, the API server trusts it by default

---

## ACT II — Injecting the CA bundle

```bash
# Get the CA certificate used to sign the webhook cert
kubectl get secret webhook-tls -n webhooks -o jsonpath='{.data.ca\.crt}'
```

```
LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...
```

```bash
CA_BUNDLE=$(kubectl get secret webhook-tls -n webhooks \
  -o jsonpath='{.data.ca\.crt}')

kubectl patch validatingwebhookconfiguration internal-validator \
  --type=json \
  -p="[{\"op\":\"replace\",\"path\":\"/webhooks/0/clientConfig/caBundle\",\"value\":\"${CA_BUNDLE}\"}]"
```

Or, using cert-manager's CA injector (preferred for automation):

```yaml
metadata:
  annotations:
    cert-manager.io/inject-ca-from: webhooks/webhook-tls-cert
```

cert-manager automatically keeps the `caBundle` updated whenever the certificate is renewed.

---

## EPILOGUE

*"A webhook with an empty caBundle causes every API call that triggers it to fail with 'certificate signed by unknown authority'. Always populate caBundle with the CA that signed your webhook cert. Use cert-manager's CA injector to keep it automatically updated."*

> **Inspector Ahmed's Rule #84:** Webhook failing with 'certificate signed by unknown authority'? Check `caBundle` in the webhook configuration. It must contain the CA cert that signed the webhook's TLS cert. Use cert-manager CA injector to automate this.
