# 100 Shades of Kubernetes

## Episode 1: The Case of the Silent Pod

**Diagnostic Focus:** `CrashLoopBackOff` caused by a missing ConfigMap / Failed Application Entrypoint.

---

### [SCENE START]

**INT. INSPECTOR AHMED'S OFFICE — NIGHT**

Rain lashes against the window. The room is dark, lit only by the harsh, flickering neon glow of a dual-monitor setup. On screen, a terminal window scrolls endlessly with red error messages.

**INSPECTOR AHMED (V.O.)**
> *Cluster `prod-eu-west-01`. 3:00 AM. That's when the good pods go to sleep, and the bad ones go to hell. I was on my third cup of stale coffee when the page came in. The checkout service was down. Dead in the water. Management was screaming about lost revenue. Another night in Kube-City.*

Ahmed takes a slow sip of hot espresso, leans forward, and hits the keyboard.

```bash
kubectl get pods -n production
```

The output hits the screen. One pod stands out like a chalk outline at a crime scene.

```
NAME                                READY   STATUS             RESTARTS   AGE
checkout-service-67bf7c9754-x92ll   0/1     CrashLoopBackOff   6          12m
```

**AHMED** *(squinting at the screen)*

`CrashLoopBackOff`. The classic. It's not dead, and it's not alive. It's trapped in a purgatory of its own making. It starts up, gasps for air, dies, and the Kubelet kicks it back down to try again. Let's see what the coroner's report says.

Ahmed types furiously.

```bash
kubectl describe pod checkout-service-67bf7c9754-x92ll -n production
```

---

### [THE INVESTIGATION]

Ahmed scans the massive wall of text. He bypasses the usual fluff and heads straight for the **Events** and **Containers** sections.

**INSPECTOR AHMED (V.O.)**
> *In this business, you learn to look at the footprints. The `State` says `Waiting`, the `Reason` says `CrashLoopBackOff`. But look closer at the `Last State`. `Exit Code: 1`. That means the application inside the container actively decided to quit. It wasn't murdered by the OOMKiller — that would be `Exit Code: 137`. No, this was an inside job.*

Ahmed zooms in on the container runtime configuration.

```yaml
Containers:
  checkout-app:
    Command:
      /app/server
    Args:
      --config=/etc/config/settings.yaml
```

**AHMED**

It's looking for its ledger. `/etc/config/settings.yaml`. Let's look at the logs. If a pod dies, it usually leaves a dying declaration.

```bash
kubectl logs checkout-service-67bf7c9754-x92ll -n production
```

**Terminal output:**

```
Error: failed to open config file at /etc/config/settings.yaml: open /etc/config/settings.yaml: no such file or directory
```

**AHMED**

The file is missing. The application expects its instructions, finds nothing, and panics. But why is the file missing? It's supposed to be mounted from a ConfigMap.

Ahmed scrolls back up his `describe` output to check the **Volumes** section.

```yaml
Volumes:
  config-volume:
    Type:      ConfigMap (a volume populated by a ConfigMap)
    Name:      checkout-config
    Optional:  false
```

**AHMED**

It's looking for a ConfigMap named `checkout-config`. Let's see if this suspect even exists in our city.

```bash
kubectl get configmap checkout-config -n production
```

**Terminal output:**

```
Error from server (NotFound): configmaps "checkout-config" not found
```

---

### [THE REVEAL]

Ahmed stands up, walks over to a whiteboard, and draws a quick diagram of a Pod, a Volume mount, and a missing ConfigMap pointer.

```
       +---------------------------------------------+
       |                 KUBERNETES POD              |
       |                                             |
       |  +------------------+     +--------------+  |
       |  |  Container app   |     | Volume Mount |  |
       |  |  (/app/server)   |     | /etc/config/ |  |
       |  +--------+---------+     +-------+------+  |
       |           |                       |         |
       +-----------|-----------------------|---------+
                   |                       |
      Attempts to read settings.yaml       | Looks up Reference
                   |                       v
                   v               [checkout-config]
          (!!! FILE MISSING !!!)           |
                   |                       v
                   +==========>>  🚨 404 NOT FOUND IN CLUSTER!
```

**AHMED** *(speaking directly to camera)*

Here is how the scam works. When you tell a Deployment to mount a ConfigMap as a volume, Kubernetes relies on that ConfigMap existing. If the `Optional` flag is set to `false` (which is the default), and that ConfigMap isn't there — the pod can behave in two ways depending on how it's configured.

- **Scenario A — The Usual Way:** If the ConfigMap is missing at the kubelet level during creation, the pod won't even start. It stays stuck in `ContainerCreating` or `CreateContainerConfigError`.
- **Scenario B — Our Case:** The ConfigMap was present when the deployment was initially verified, or the container started via a specialised entrypoint script that bypasses initial checks but fails the moment the binary executes and looks for the path. Another common trace: someone deleted `checkout-config` right after the rollout started, leaving existing containers to crash on restart.

Ahmed turns back to the monitor.

**AHMED**

Let's check the cluster events to see who deleted our missing witness.

```bash
kubectl get events -n production --sort-by='.metadata.creationTimestamp'
```

He finds the smoking gun: a junior developer's automated service account token associated with a `delete configmap` command from 15 minutes ago.

**AHMED**

Classic rookie mistake. They cleaned up "unused" resources using an outdated cleanup script before the new deployment finished rolling out.

---

### [THE RESOLUTION]

Ahmed crafts a quick fix. He recreates the missing ConfigMap with the required production variables.

```bash
kubectl create configmap checkout-config \
  --from-file=settings.yaml=/tmp/recovered-settings.yaml \
  -n production
```

He watches the terminal with a steady eye.

```bash
kubectl get pods -n production -w
```

```
NAME                                READY   STATUS    RESTARTS   AGE
checkout-service-67bf7c9754-x92ll   1/1     Running   0          14s
```

The red text disappears. Beautiful, steady green lines take over.

**INSPECTOR AHMED (V.O.)**
> *The pod stopped crashing. The traffic started flowing again. Another soul saved in Kube-City. But there are 99 more issues out there waiting in the dark. Full disks, rogue network policies, silent RBAC failures... They think they can hide behind the abstraction layers. But they forget one thing — I have `kubectl`.*

Ahmed closes his laptop, grabs his trench coat, and walks out into the night.

---

### [SCENE END]
