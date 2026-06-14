# Episode 78 — "The Secret Store Timeout"
### *Inspector Ahmed and the External Secrets that never arrive*

**Culprit:** External Secrets Operator can't reach Vault — network policy blocks egress to secrets store
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `external-secrets` `vault` `networkpolicy` `egress` `secrets-management`

---

## OPENING — Crime scene

"The External Secrets Operator was installed. SecretStore was configured. ExternalSecret resources were created. But no Kubernetes Secrets appeared. The operator was silent. The secrets were stranded."

```bash
kubectl get externalsecret -n production
```

```
NAME          STORE         REFRESH   STATUS         READY
db-password   vault-store   1h        SecretSyncError   False
```

`SecretSyncError`. The sync failed.

```bash
kubectl describe externalsecret db-password -n production
```

```
Status:
  Conditions:
  - Type: Ready
    Status: "False"
    Reason: SecretSyncError
    Message: could not fetch secret data: error calling Vault API:
             Post "https://vault.secrets.svc:8200/v1/secret/data/production/db":
             context deadline exceeded (Client.Timeout exceeded)
```

Timeout reaching Vault. The External Secrets Operator can't connect to the Vault service.

---

## ACT I — Network path

```bash
kubectl get pod external-secrets-7f9d-xk2p -n external-secrets \
  -o yaml | grep -i "namespace"
```

```
namespace: external-secrets
```

The operator is in the `external-secrets` namespace. Vault is in `secrets`. Ahmed checks egress NetworkPolicy:

```bash
kubectl get networkpolicy -n external-secrets
```

```
NAME                    POD-SELECTOR   AGE
deny-all-egress         <none>         30d
allow-dns-egress        <none>         30d
```

`deny-all-egress` plus `allow-dns-egress`. No rule permits egress to the `secrets` namespace.

---

## ACT II — Adding the egress rule

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-vault-egress
  namespace: external-secrets
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: external-secrets
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: secrets
    ports:
    - protocol: TCP
      port: 8200
```

```bash
kubectl apply -f allow-vault-egress.yaml
```

Wait for the next sync (or force it):

```bash
kubectl annotate externalsecret db-password -n production \
  force-sync=$(date +%s) --overwrite
```

```bash
kubectl get secret db-password -n production
```

```
NAME          TYPE     DATA   AGE
db-password   Opaque   1      5s
```

Secret arrived.

---

## EPILOGUE

*"External Secrets Operator needs network access to the secrets store. If NetworkPolicy blocks egress from the operator namespace to the Vault/AWS SSM/GCP Secret Manager endpoint, secrets never arrive. Always check egress paths when ESO shows timeout errors."*

> **Inspector Ahmed's Rule #78:** ExternalSecret shows SecretSyncError with timeout? Check NetworkPolicy egress from the operator namespace to the secrets store. Add an explicit egress allow rule.
