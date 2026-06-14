# Episode 2 — "The Ghost Image"
### *Inspector Ahmed and the container that doesn't exist*

**Culprit:** Wrong image tag pushed to a registry that doesn't have it
**Difficulty:** ⭐ Beginner
**Tags:** `imagepullbackoff` `registry` `image` `deployment`

---

## OPENING — Crime scene

"The CI pipeline said green. The deploy script said successful. And yet — no pod was serving traffic. It had been twelve minutes. The on-call engineer had already rebooted the deployment twice, making things worse, not better."

Ahmed gets the alert. He doesn't reboot anything.

```bash
kubectl get pods -n production
```

```
NAME                           READY   STATUS             RESTARTS   AGE
frontend-6d8f9c-tz4xp          0/1     ImagePullBackOff   0          12m
frontend-6d8f9c-9wkl2          0/1     ImagePullBackOff   0          12m
```

`ImagePullBackOff`. Ahmed recognises the suspect immediately. But he never assumes. He verifies.

---

## ACT I — Reading the mugshot

```bash
kubectl describe pod frontend-6d8f9c-tz4xp -n production
```

Down to Events:

```
Events:
  Type     Reason          Age                From               Message
  ----     ------          ----               ----               -------
  Normal   Pulling         12m                kubelet            Pulling image
                                                                  "gcr.io/mycompany/frontend:v2.4.1-rc3"
  Warning  Failed          12m                kubelet            Failed to pull image
                                                                  "gcr.io/mycompany/frontend:v2.4.1-rc3":
                                                                  rpc error: code = NotFound
                                                                  desc = failed to pull and unpack image:
                                                                  failed to resolve reference
                                                                  "gcr.io/mycompany/frontend:v2.4.1-rc3":
                                                                  not found
  Warning  BackOff         11m (x6 over 11m)  kubelet            Back-off pulling image
                                                                  "gcr.io/mycompany/frontend:v2.4.1-rc3"
```

*Not found.* The image tag `v2.4.1-rc3` doesn't exist in the registry. The kubelet tried to pull it, failed, and is now in backoff — waiting longer and longer between retries.

> **📚 Teaching moment — ImagePullBackOff vs ErrImagePull**
>
> You'll see two related statuses:
> - **ErrImagePull**: the kubelet just tried and failed to pull the image — the *fresh* failure state
> - **ImagePullBackOff**: the kubelet has failed multiple times and is now backing off — waiting exponentially longer between attempts (10s, 20s, 40s, up to 5 minutes)
>
> Neither means the node is broken. Both mean: *the image could not be fetched.* Reasons include: tag doesn't exist, wrong registry URL, registry is down, or missing pull credentials.

---

## ACT II — Verifying the registry

Ahmed checks what tag was actually pushed by the CI pipeline.

```bash
# Check what image the deployment is configured to use
kubectl get deployment frontend -n production -o jsonpath='{.spec.template.spec.containers[0].image}'
```

```
gcr.io/mycompany/frontend:v2.4.1-rc3
```

Now he checks the registry directly:

```bash
gcloud container images list-tags gcr.io/mycompany/frontend --limit=5
```

```
DIGEST         TAGS                  TIMESTAMP
sha256:a9f2…   v2.4.1-rc2            2024-03-11T08:22:14
sha256:7bc1…   v2.4.0                2024-03-10T14:05:33
sha256:3ef9…   v2.3.9                2024-03-08T09:11:20
```

There it is. `v2.4.1-rc3` was never pushed. The CI pipeline built the image with tag `v2.4.1-rc2`, but someone updated the deployment manifest with a tag that didn't exist yet — or made a typo.

---

## ACT III — The interrogation

Ahmed checks the git history of the deployment manifest:

```bash
git log --oneline -5 -- k8s/production/frontend-deployment.yaml
```

```
a3f8c12  chore: bump frontend image to v2.4.1-rc3
d91e045  fix: increase memory limit for frontend
b7f3a91  feat: add readiness probe to frontend
```

```bash
git show a3f8c12
```

```diff
-        image: gcr.io/mycompany/frontend:v2.4.1-rc2
+        image: gcr.io/mycompany/frontend:v2.4.1-rc3
```

Committed 15 minutes ago. By a developer who was "just preparing for the next release" and accidentally applied the manifest before the CI job finished — before the image existed.

> **📚 Teaching moment — imagePullPolicy**
>
> Kubernetes has three image pull policies:
> - **Always**: pull from registry every time the pod starts — guarantees freshness, adds latency
> - **IfNotPresent**: only pull if the image is not already cached on the node — default for tags other than `latest`
> - **Never**: only use cached images — useful for air-gapped environments
>
> If you use `latest` as a tag (please don't in production), the default policy becomes `Always`. A specific semver tag defaults to `IfNotPresent` — which is why in this case the kubelet actually tried to pull and got `NotFound`, rather than silently using a stale cached image.

---

## ACT IV — The arrest

**Presenting problem:** Pods in `ImagePullBackOff`, application down.

**Root cause:** Deployment manifest referenced image tag `v2.4.1-rc3` which had not yet been built or pushed to the registry.

```bash
# Roll back to the last working image
kubectl set image deployment/frontend \
  frontend=gcr.io/mycompany/frontend:v2.4.1-rc2 \
  -n production
```

```bash
kubectl rollout status deployment/frontend -n production
```

```
Waiting for deployment "frontend" rollout to finish: 1 out of 2 new replicas have been updated...
deployment "frontend" successfully rolled out
```

Application restored.

---

## EPILOGUE

*"A green pipeline means the code compiled. It says nothing about the tag in the manifest. Always check that what you deployed actually exists in the registry."*

> **📚 Episode takeaways**
>
> | Command | What it's for |
> |---|---|
> | `kubectl describe pod <pod>` | See the exact image pull error |
> | `kubectl get deployment -o jsonpath` | Extract the exact image being used |
> | `kubectl set image deployment/...` | Quick fix without editing YAML |
> | `kubectl rollout status` | Watch the rollout complete |
>
> **Inspector Ahmed's Rule #2:** `ImagePullBackOff` is never a cluster problem. It's always an image problem. Check the tag, check the registry, check the credentials — in that order.
