# Episode 36 — "The Runaway Train"
### *Inspector Ahmed and the deployment that deleted production data*

**Culprit:** Incorrect namespace in kubectl context — command ran against wrong cluster
**Difficulty:** ⭐ Beginner (but devastating)
**Tags:** `kubectl-context` `namespace` `human-error` `safety`

---

## OPENING — Crime scene

"A developer ran `kubectl delete deployment api`. They thought they were in staging. They were in production. The deployment was gone. The PVCs were intact — but the service was down."

This is not a Kubernetes bug. This is the most common and most painful human error in Kubernetes operations.

---

## ACT I — The wrong context

```bash
kubectl config get-contexts
```

```
CURRENT   NAME                    CLUSTER           AUTHINFO    NAMESPACE
          staging                 staging-cluster   staging     staging
*         production              prod-cluster      prod-admin  production
```

The `*` was on production. The developer didn't check.

> **📚 Teaching moment — Safe kubectl practices**
>
> Never run destructive commands without verifying your context first.
>
> **Defensive habits:**
> 1. Always check: `kubectl config current-context`
> 2. Use kubectx/kubens for fast, visible context switching
> 3. Add context name to your shell prompt (kube-ps1)
> 4. Use `--namespace` and `--context` flags explicitly in scripts
> 5. Apply RBAC: production cluster should not give developers `delete` on Deployments
> 6. Use admission webhooks to require confirmation for destructive operations

---

## ACT II — The recovery

```bash
# Restore from Helm release (if deployed with Helm)
helm rollback api 1 -n production

# Or restore from GitOps (if using ArgoCD/Flux)
# ArgoCD would auto-reconcile within minutes

# Or re-apply from git
git checkout HEAD -- k8s/production/api-deployment.yaml
kubectl apply -f k8s/production/api-deployment.yaml
```

Deployment restored. Service back up within 2 minutes.

**Post-incident action — install safeguards:**

```bash
# Install kubectx for visible context management
brew install kubectx

# Add kube-ps1 to shell prompt to always see current context
# ~/.bashrc or ~/.zshrc:
source "/usr/local/opt/kube-ps1/share/kube-ps1.sh"
PS1='$(kube_ps1)'$PS1
```

---

## EPILOGUE

*"The most dangerous command in Kubernetes is `kubectl delete` run with the wrong context. It takes 0.3 seconds to destroy what took 3 months to build. Make your current context visible at all times. Make production harder to accidentally target."*

> **Inspector Ahmed's Rule #36:** Before any destructive command, run `kubectl config current-context`. Set up kube-ps1 so the context is always visible in your prompt. Treat this as non-negotiable.
