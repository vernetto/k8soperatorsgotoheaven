# Episode 45 — "The Webhook Trap"
### *Inspector Ahmed and the admission webhook that breaks everything*

**Culprit:** Validating webhook with `failurePolicy: Fail` and broken webhook service — all pod creates fail
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `admission-webhook` `validatingwebhook` `failurepolicy` `api-server`

---

## OPENING — Crime scene

"No pods could be created. No deployments could roll out. No jobs could run. Every `kubectl apply` returned an error from a webhook — a webhook whose service had been deleted three weeks ago."

```bash
kubectl apply -f deployment.yaml
```

```
Error from server (InternalError): error when creating "deployment.yaml":
  Internal error occurred: failed calling webhook
  "validate.policy.company.com":
  failed to call webhook: Post
  "https://policy-webhook.webhook-system.svc:443/validate":
  service "policy-webhook" not found
```

An admission webhook is failing because its backing service doesn't exist.

> **📚 Teaching moment — Admission webhooks and failurePolicy**
>
> Admission webhooks intercept API server requests (creates, updates, deletes) and either validate or mutate them. They run as services in the cluster.
>
> `failurePolicy` controls what happens if the webhook is unreachable:
> - **Fail**: the API call is rejected. All creates/updates/deletes fail until the webhook is fixed.
> - **Ignore**: the webhook failure is silently ignored and the request proceeds.
>
> A webhook with `failurePolicy: Fail` whose service is deleted effectively **locks the entire cluster** — nothing can be created or updated until the webhook is fixed.

---

## ACT I — Finding the webhook

```bash
kubectl get validatingwebhookconfigurations
```

```
NAME                     WEBHOOKS   AGE
policy-validator         1          180d
```

```bash
kubectl describe validatingwebhookconfiguration policy-validator
```

```
  Failure Policy: Fail
  Service:
    Namespace: webhook-system
    Name:      policy-webhook
```

```bash
kubectl get svc policy-webhook -n webhook-system
```

```
Error from server (NotFound): services "policy-webhook" not found
```

The webhook service was deleted when the team decommissioned the policy system — but the webhook configuration was left behind.

---

## ACT II — The emergency fix

**Option A — Delete the webhook configuration (if policy is no longer needed):**

```bash
kubectl delete validatingwebhookconfiguration policy-validator
```

**Option B — Change failurePolicy to Ignore (temporary):**

```bash
kubectl patch validatingwebhookconfiguration policy-validator \
  --type='json' \
  -p='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"}]'
```

**Option C — Restore the webhook service** if the policy is still needed.

Ahmed goes with Option A — the policy system was intentionally decommissioned.

```bash
kubectl apply -f deployment.yaml
```

```
deployment.apps/api created
```

---

## EPILOGUE

*"A webhook with failurePolicy:Fail is a loaded gun pointed at your cluster. If the webhook service disappears, you can't create anything. Always pair failurePolicy:Fail webhooks with robust service monitoring. When decommissioning a webhook service, always delete the webhook configuration first."*

> **Inspector Ahmed's Rule #45:** All creates/updates failing with webhook error? `kubectl get validatingwebhookconfigurations`. Find the one pointing to a dead service. Delete it or set failurePolicy:Ignore as emergency fix.
