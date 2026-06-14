# Episode 8 — "The Unclaimed Luggage"
### *Inspector Ahmed and the volume that was never born*

**Culprit:** PersistentVolumeClaim references a StorageClass that doesn't exist
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `pvc` `persistentvolume` `storageclass` `storage` `pending`

---

## OPENING — Crime scene

"A stateful application deployed to a new cluster. The Helm chart was copy-pasted from the old cluster. Everything looked right. But the pod sat in `Pending`, and the volume it needed was nowhere to be found."

```bash
kubectl get pods -n database
```

```
NAME                     READY   STATUS    RESTARTS   AGE
postgres-0               0/1     Pending   0          15m
```

Ahmed has seen this movie before. Stateful pod + Pending = storage problem.

---

## ACT I — Following the volume

```bash
kubectl describe pod postgres-0 -n database
```

```
Events:
  Type     Reason            Age   From               Message
  ----     ------            ----  ----               -------
  Warning  FailedScheduling  15m   default-scheduler  0/3 nodes are available:
                                                       pod has unbound immediate
                                                       PersistentVolumeClaims.
```

Unbound PVC. The pod is waiting for a volume that doesn't exist yet.

```bash
kubectl get pvc -n database
```

```
NAME                STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-postgres-0     Pending                                       fast-ssd       15m
```

The PVC is `Pending` — it was never bound to a volume.

```bash
kubectl describe pvc data-postgres-0 -n database
```

```
Events:
  Type     Reason               Age   From                     Message
  ----     ------               ----  ----                     -------
  Warning  ProvisioningFailed   15m   persistentvolume-controller
                                       storageclass.storage.k8s.io
                                       "fast-ssd" not found
```

The StorageClass `fast-ssd` does not exist on this cluster.

> **📚 Teaching moment — How dynamic provisioning works**
>
> When a PVC references a StorageClass, Kubernetes asks the corresponding provisioner (e.g. AWS EBS CSI, GCE PD, or a local provisioner) to create a PersistentVolume on demand. This is *dynamic provisioning*.
>
> If the StorageClass doesn't exist, the provisioner is never called, and the PVC stays `Pending` forever. No error kills anything — the system just waits.

---

## ACT II — Checking what's actually available

```bash
kubectl get storageclass
```

```
NAME                     PROVISIONER             AGE
standard (default)       kubernetes.io/gce-pd    90d
premium-rwo              pd.csi.storage.gke.io   90d
```

No `fast-ssd`. The old cluster (AWS-based) had an EBS StorageClass named `fast-ssd`. The new cluster is on GKE. Different cloud, different provisioners, different names.

Ahmed checks what properties `fast-ssd` had on the old cluster to find the equivalent:

```bash
# On the old cluster:
kubectl describe storageclass fast-ssd
```

```
Provisioner: ebs.csi.aws.com
Parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
```

High-performance SSD. On GKE, the equivalent is `premium-rwo`.

---

## ACT III — The fix

Two options:

**Option A — Patch the PVC to use the correct StorageClass:**

```bash
# PVCs are immutable — delete and recreate
kubectl delete pvc data-postgres-0 -n database

# Apply with corrected storageClass
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-postgres-0
  namespace: database
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: premium-rwo
EOF
```

**Option B — Create a StorageClass alias** (better for multi-environment Helm charts):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
EOF
```

Option B is cleaner for a Helm chart that will be deployed to multiple clusters: you create a `fast-ssd` StorageClass on each cluster that points to the local equivalent, and the chart never needs to change.

---

## EPILOGUE

*"StorageClass names are not portable. The Helm chart that worked perfectly on AWS knows nothing about GKE. Either abstract the name with a local alias, or make the storageClass a configurable Helm value. Never hardcode cloud-specific names in your manifests."*

> **📚 Episode takeaways**
>
> | Command | What it's for |
> |---|---|
> | `kubectl get pvc -n <ns>` | Check volume claim status |
> | `kubectl describe pvc <name>` | See provisioning error |
> | `kubectl get storageclass` | List available StorageClasses on this cluster |
> | `kubectl describe storageclass` | See provisioner and parameters |
>
> **Inspector Ahmed's Rule #8:** `Pending` PVC = missing or wrong StorageClass. Always check `kubectl get storageclass` when moving workloads between clusters.
