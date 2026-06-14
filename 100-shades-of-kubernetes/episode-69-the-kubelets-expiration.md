# Episode 69 — "The Kubelet's Expiration"
### *Inspector Ahmed and the node that goes NotReady on a schedule*

**Culprit:** Kubelet certificate expired — node goes NotReady, pods evicted
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `certificates` `kubelet` `node` `notready` `pki`

---

## OPENING — Crime scene

"A node went NotReady at 3am. Pods were evicted, rescheduled. The node came back an hour later — by itself. Then it happened again a week later. And again. The failures were systematic, not random."

```bash
kubectl describe node node-3
```

```
Conditions:
  Type                 Status  LastHeartbeatTime       Reason
  ----                 ------  -----------------       ------
  Ready                False   2024-03-14T03:00:12Z    NodeStatusUnknown
  MemoryPressure       False   2024-03-14T03:00:12Z    KubeletHasNoPressure
  DiskPressure         False   2024-03-14T03:00:12Z    KubeletHasNoPressure
```

```bash
# SSH to node-3
journalctl -u kubelet | grep -i "cert\|TLS\|expired" | tail -10
```

```
Mar 14 03:00:11 kubelet[1234]: tls: failed to verify certificate:
  x509: certificate has expired or is not yet valid:
  current time 2024-03-14T03:00:11Z is after 2024-03-14T03:00:00Z
```

The kubelet's client certificate expired at exactly 3:00am. The kubelet couldn't communicate with the API server. Node went NotReady. One hour later, the kubelet auto-renewed the certificate (if configured to do so) and came back.

> **📚 Teaching moment — Kubelet certificate rotation**
>
> The kubelet uses certificates to authenticate to the API server. By default, these certificates have a 1-year validity. Kubernetes supports automatic certificate rotation via:
> - `--rotate-certificates=true` on kubelet: kubelet requests a new certificate before expiry
> - `--feature-gates=RotateKubeletClientCertificate=true` (enabled by default in modern versions)
>
> If certificate rotation fails (e.g., the kubelet is offline when the cert would renew, or CSR approval is manual), the cert expires and the node goes NotReady at exactly the certificate expiry timestamp.

---

## ACT II — Checking certificate status

```bash
# On node-3
ls -la /var/lib/kubelet/pki/
```

```
-rw------- 1 root root 1234 Mar 14 03:01 kubelet-client-current.pem
```

The certificate renewed at 03:01 — 1 minute after failure. Auto-rotation worked but with a 1-minute gap.

To check upcoming expiry dates:

```bash
for node in $(kubectl get nodes -o name); do
  echo -n "${node}: "
  kubectl get --raw /api/v1/${node}/proxy/configz 2>/dev/null | \
    jq -r '.kubeletconfig.tlsCertFile' 2>/dev/null || echo "N/A"
done
```

For monitoring, check certificate expiry:

```bash
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem \
  -noout -enddate
```

```
notAfter=Mar 14 03:00:00 2025 GMT
```

---

## EPILOGUE

*"Nodes that go NotReady at exactly the same time of day — and come back an hour later — have certificate expiry problems. Kubelet auto-rotation handles this, but only if rotation was enabled from the start. Check certificate dates on all nodes. Set alerts for expiry approaching within 30 days."*

> **Inspector Ahmed's Rule #69:** Node NotReady at a specific time, recovering automatically? Check kubelet certificate expiry. `openssl x509 -noout -enddate` on the cert. Enable `--rotate-certificates=true` if not set.
