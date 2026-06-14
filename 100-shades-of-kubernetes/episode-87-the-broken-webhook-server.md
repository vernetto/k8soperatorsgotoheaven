# Episode 87 — "The Broken Webhook Server"
### *Inspector Ahmed and the HTTPS server that fails the TLS handshake*

**Culprit:** Webhook server certificate missing the SAN for the Kubernetes service DNS name
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `webhook` `tls` `san` `certificate` `admission`

---

## OPENING — Crime scene

"A validating webhook was deployed. The caBundle was correctly set. The webhook service existed. But every admission call returned a TLS error. The certificate was valid — but for the wrong name."

```bash
kubectl apply -f test-resource.yaml
```

```
Error from server (InternalError): Internal error occurred:
  failed calling webhook "validate.internal.company.com":
  Post "https://validator-svc.webhooks.svc:8443/validate":
  x509: certificate is valid for validator-svc.webhooks.svc.cluster.local,
  not validator-svc.webhooks.svc
```

`certificate is valid for ... not ...`. The certificate has a Subject Alternative Name (SAN) but for the wrong DNS variant.

---

## ACT I — The SAN requirements

When the API server connects to a webhook at `https://validator-svc.webhooks.svc:8443`, it checks that the certificate's SAN includes the exact hostname it's connecting to.

The certificate was generated with only `validator-svc.webhooks.svc.cluster.local` as the SAN. But the API server is connecting to `validator-svc.webhooks.svc` (without the `.cluster.local` suffix).

> **📚 Teaching moment — TLS SANs for internal Kubernetes services**
>
> For a webhook service `my-webhook` in namespace `webhooks`, the certificate must include ALL of these as SANs:
> - `my-webhook`
> - `my-webhook.webhooks`
> - `my-webhook.webhooks.svc`
> - `my-webhook.webhooks.svc.cluster.local`
>
> The API server may connect using any of these forms. Missing any one can cause TLS failures.
>
> With cert-manager, use a `Certificate` resource that specifies all four DNS names:
> ```yaml
> spec:
>   dnsNames:
>   - my-webhook
>   - my-webhook.webhooks
>   - my-webhook.webhooks.svc
>   - my-webhook.webhooks.svc.cluster.local
> ```

---

## ACT II — Regenerating the certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: validator-tls
  namespace: webhooks
spec:
  secretName: validator-tls
  issuerRef:
    name: internal-ca
    kind: ClusterIssuer
  dnsNames:
  - validator-svc
  - validator-svc.webhooks
  - validator-svc.webhooks.svc
  - validator-svc.webhooks.svc.cluster.local
```

After cert-manager issues the new certificate and the webhook server restarts with it:

```bash
kubectl apply -f test-resource.yaml
```

```
testresource.internal.company.com/test created
```

---

## EPILOGUE

*"TLS SANs for internal Kubernetes services must include all four DNS name forms. Missing the short form `service.namespace.svc` while only having the full FQDN is a very common mistake. Always include all four when generating webhook certificates."*

> **Inspector Ahmed's Rule #87:** Webhook TLS error 'certificate is valid for X not Y'? The cert is missing a SAN. Regenerate with all four forms: `svc`, `svc.ns`, `svc.ns.svc`, `svc.ns.svc.cluster.local`. Use cert-manager to automate this.
