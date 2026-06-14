# Episode 35 — "The Misaligned Clock"
### *Inspector Ahmed and the JWT that always expires too soon*

**Culprit:** Node clock drift — tokens validated against wrong time
**Difficulty:** ⭐⭐ Intermediate
**Tags:** `time` `ntp` `jwt` `clock-drift` `certificates`

---

## OPENING — Crime scene

"Authentication was failing for some users, intermittently. The tokens were freshly issued. The error: `token is expired`. Ahmed had seen this before — when the clocks in a cluster don't agree."

```bash
kubectl logs auth-service-7f9d4b-xk2p -n production | grep expired
```

```
[ERROR] JWT validation failed: token is expired by 4m22s
```

A 4-minute expiry offset on a freshly issued token. The token was generated on one node and validated on another — and those two nodes have different clocks.

---

## ACT I — Checking node time

```bash
for node in $(kubectl get nodes -o name); do
  echo -n "$node: "
  kubectl debug node/${node##node/} -it --image=busybox -- date 2>/dev/null | tail -1
done
```

```
node/node-1: Tue Mar 14 10:22:14 UTC 2024
node/node-2: Tue Mar 14 10:22:18 UTC 2024
node/node-3: Tue Mar 14 10:18:02 UTC 2024   ← 4 minutes behind
```

`node-3` is 4 minutes behind. The auth pod runs on `node-3` (issues tokens with node-3's time). The validation pod runs on `node-1` (validates against node-1's time). 4 minutes of drift = 4-minute-old tokens = expired.

> **📚 Teaching moment — Why time matters in Kubernetes**
>
> Clock accuracy is critical for:
> - **JWT / OAuth tokens** — issued_at and expiry checked against current time
> - **TLS certificates** — validity windows
> - **etcd** — Raft consensus protocol sensitive to clock drift
> - **Kubernetes API** — audit log timestamps, lease renewals
>
> NTP (Network Time Protocol) should be running on all nodes. On cloud VMs, the hypervisor usually handles this. But after a VM suspension/resume, or a network partition, drift can occur.

---

## ACT II — Fixing the clock

```bash
# SSH to node-3 and resync
ssh node-3
systemctl restart systemd-timesyncd
timedatectl status
```

```
System clock synchronized: yes
NTP service: active
```

Alternatively, if chrony is used:

```bash
chronyc makestep  # force immediate time sync
```

Within minutes, clock drift is resolved. JWT validation normalises.

---

## EPILOGUE

*"Four minutes of clock drift. Four minutes of authentication failures. Every node must have NTP running. After any incident involving VM suspension or network issues, check `timedatectl` on all nodes."*

> **Inspector Ahmed's Rule #35:** Intermittent auth failures with 'token expired' for fresh tokens = clock drift. Check `date` on all nodes. Restart NTP service on the drifted node.
