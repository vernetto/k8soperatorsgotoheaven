# 100 Shades of Kubernetes

## Episode 1 – The Case of the Missing Website

### Concepts Covered

- kubectl get
- kubectl describe
- kubectl logs
- Services
- Labels
- Selectors
- Endpoints

---

# Opening Scene

A dark room.

03:17 AM.

The phone rings.

Ahmed opens one eye.

**Nina (SRE):**

> Ahmed! The production website is down!

**Ahmed:**

> Again?

**Nina:**

> Customers cannot access the application.
> Marketing is panicking.
> Sales is panicking.
> Even the CEO is panicking.

**Ahmed:**

> Is Kubernetes panicking?

**Nina:**

> Kubernetes never panics.
> That's why I called you.

---

# The Crime Scene

Ahmed opens Lens.

He sees:

```bash
kubectl get pods
```

Output:

```text
NAME                    READY   STATUS
web-7b65c4f7f8-x1d2a   1/1     Running
web-7b65c4f7f8-k9m4z   1/1     Running
web-7b65c4f7f8-l8f3n   1/1     Running
```

Everything looks healthy.

Ahmed thinks:

> Interesting.
>
> Pods are alive.
>
> Yet the website is dead.
>
> Somebody is lying.

---

# First Clue

He checks the service.

```bash
kubectl get svc
```

Output:

```text
NAME      TYPE        CLUSTER-IP
web-svc   ClusterIP   10.96.15.33
```

Looks normal.

Nina tries:

```bash
curl http://web-svc
```

Result:

```text
Connection timed out
```

---

# Ahmed's Theory

Ahmed lights an imaginary cigar.

> A Service doesn't forward traffic itself.
>
> It forwards traffic to endpoints.
>
> Let's see the endpoints.

```bash
kubectl get endpoints web-svc
```

Output:

```text
NAME      ENDPOINTS   AGE
web-svc   <none>      2d
```

Ahmed smiles.

---

# Detective Explanation

A Kubernetes Service does not magically know where pods are.

It uses a selector such as:

```yaml
selector:
  app: web
```

to discover matching pods.

Those pods become endpoints.

No endpoints = nowhere to send traffic.

---

# Back to the Investigation

Ahmed inspects the service.

```bash
kubectl describe svc web-svc
```

Output:

```text
Selector:
  app=web
```

Now he inspects the pods.

```bash
kubectl get pods --show-labels
```

Output:

```text
NAME                    LABELS
web-7b65c4f7f8-x1d2a   app=frontend
web-7b65c4f7f8-k9m4z   app=frontend
web-7b65c4f7f8-l8f3n   app=frontend
```

Ahmed freezes.

---

# The Smoking Gun

The Service expects:

```yaml
app=web
```

The pods have:

```yaml
app=frontend
```

No match.

No endpoints.

No traffic.

Website dead.

---

# Reconstruction of the Crime

Yesterday a developer changed:

```yaml
labels:
  app: web
```

to:

```yaml
labels:
  app: frontend
```

because:

> "frontend sounds more modern."

He forgot to update the Service selector.

---

# The Fix

Patch the Service:

```yaml
selector:
  app: frontend
```

Apply:

```bash
kubectl apply -f service.yaml
```

Check again:

```bash
kubectl get endpoints web-svc
```

Output:

```text
NAME
web-svc

10.244.1.17:8080
10.244.1.18:8080
10.244.2.11:8080
```

Test:

```bash
curl http://web-svc
```

Result:

```html
Welcome to Production
```

---

# Resolution

The CEO sends an email.

> Excellent work.
>
> We avoided catastrophe.

Ahmed closes the laptop.

Outside, thunder rolls.

Another incident awaits.

---

# Lessons Learned

When an application is unreachable:

### Check pods

```bash
kubectl get pods
```

### Check services

```bash
kubectl get svc
```

### Check endpoints

```bash
kubectl get endpoints
```

### Check labels

```bash
kubectl get pods --show-labels
```

### Check selectors

```bash
kubectl describe svc
```

---

# Final Reveal

**Culprit:** Label/Selector mismatch

**Murder weapon:** Wrong label

**Victim:** Service endpoints

**Damage:** Entire website unavailable

**Inspector Ahmed Difficulty Rating:** ⭐☆☆☆☆ (Easy)

---

## Next Episode

**The Pod That Looked Healthy**

Everything is Running and Ready, but the application restarts every few minutes because of an OOMKilled condition hidden in the container history.

Topics:

- describe pod
- restart count
- container states
- requests and limits
- OOMKilled
