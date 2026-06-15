# Episode 73 — "The Secret Leak"
### *Inspector Ahmed and the credential that ended up in the wrong place*

**Culprit:** Secrets encryption at rest not configured — etcd contains plaintext secrets
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `secrets` `encryption` `etcd` `security` `compliance`

---

## OPENING — Crime scene

"A security audit found that Kubernetes Secrets stored in etcd were readable in plaintext. Anyone with access to the etcd backup files — or to the etcd data directory — could read every password, token, and certificate private key in the cluster."

```bash
# Simulate reading a secret directly from etcd
ETCDCTL_API=3 etcdctl get /registry/secrets/production/db-credentials \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key
```

```
/registry/secrets/production/db-credentials
k8s
...
database-password: s3cr3t-pr0duction-p@ssw0rd
```

Plaintext. Readable without any Kubernetes authentication.

> **📚 Teaching moment — Encryption at rest**
>
> By default, Kubernetes Secrets are stored in etcd **base64-encoded, not encrypted**. base64 is encoding, not encryption — anyone with etcd access can decode it trivially.
>
> To encrypt secrets at rest, configure an `EncryptionConfiguration` and specify it in the API server manifest. Supported providers:
> - **aesgcm** / **aescbc**: symmetric key encryption — fast but key management is manual
> - **kms**: integrates with cloud KMS (AWS KMS, GCP Cloud KMS, Azure Key Vault) — keys managed externally
> - **identity**: no encryption (default)
>
> Encryption is applied on write — existing secrets must be rewritten after enabling encryption.

---

## ACT II — Enabling encryption

```yaml
# /etc/kubernetes/encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aesgcm:
      keys:
      - name: key1
        secret: <base64-encoded-32-byte-key>
  - identity: {}   # fallback for existing unencrypted data
```

Add to the API server manifest:

```bash
# /etc/kubernetes/manifests/kube-apiserver.yaml
- --encryption-provider-config=/etc/kubernetes/encryption-config.yaml
```

After API server restarts, force-rewrite all secrets to apply encryption:

```bash
kubectl get secrets --all-namespaces -o json | \
  kubectl replace -f -
```

Now etcd stores encrypted data:

```bash
ETCDCTL_API=3 etcdctl get /registry/secrets/production/db-credentials ...
```

```
/registry/secrets/production/db-credentials
k8s:enc:aesgcm:v1:key1:Lm9FZx...  (encrypted binary)
```

---

## EPILOGUE

*"Kubernetes Secrets are not secret by default. They are base64-encoded strings in etcd. Anyone who can read etcd reads your passwords. Enable encryption at rest on day one. If you haven't: enable it now, then rewrite all secrets."*

> **Inspector Ahmed's Rule #73:** Secrets in etcd are plaintext by default. Enable EncryptionConfiguration with aesgcm or KMS. Force-rewrite all secrets after enabling. This is non-negotiable in any production cluster.
