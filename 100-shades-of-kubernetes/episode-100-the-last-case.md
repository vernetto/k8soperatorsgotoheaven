# Episode 100 — "The Last Case"
### *Inspector Ahmed and the cluster that was nobody's responsibility*

**Culprit:** No runbook, no on-call, no ownership — the cluster fails and nobody knows what to do
**Difficulty:** ⭐⭐⭐⭐ Expert
**Tags:** `runbook` `on-call` `ownership` `documentation` `process` `culture`

---

## OPENING — The final case

"It was a Sunday evening. The cluster was down. Three engineers were paged. None of them had been on-call before. None of them had access to the cluster. The runbook URL in the alert pointed to a 404. The Slack channel had no response. The postmortem would later identify the root cause as not a technical failure — but an organisational one."

This is Episode 100. There is no `kubectl describe` command that fixes it. There is no patch, no rollback, no `--force`. This is the failure behind the failures.

---

## ACT I — The technical post-mortem is not enough

Ahmed sat down the week after the incident. He wrote one sentence at the top of the postmortem:

*"Every technical failure in this list of 99 episodes could have been diagnosed and resolved in minutes — if the right person had been paged, had the right access, knew where to start, and had a runbook to follow."*

The cluster had survived 99 kinds of failures. It didn't survive the 100th: nobody owning it.

---

## ACT II — What "ownership" actually means

> **📚 The non-technical checklist**
>
> Before you ship a Kubernetes cluster to production, verify:
>
> **Access**
> - [ ] At least 3 engineers have cluster admin access
> - [ ] Credentials are not stored only on one person's laptop
> - [ ] Emergency access procedure documented and tested
>
> **Alerting**
> - [ ] Alerts fire for: node NotReady, pods CrashLoopBackOff, etcd down, API server unavailable, disk pressure, certificate expiry
> - [ ] Alerts go to a team channel AND a PagerDuty/OpsGenie rotation — not just one person's email
> - [ ] Alert runbooks are linked from the alert body
>
> **Runbooks**
> - [ ] One runbook per alert type, explaining: what this alert means, initial triage steps, escalation path
> - [ ] Runbooks are version-controlled, not in someone's personal Notion
> - [ ] Runbooks are reviewed quarterly
>
> **On-call**
> - [ ] Rotation documented with at least 2 people per shift
> - [ ] Escalation path defined (who wakes up if primary doesn't respond in 15 minutes)
> - [ ] On-call engineers have practiced incident response in a staging environment
>
> **Inventory**
> - [ ] Cluster name, cloud account, region documented
> - [ ] All namespaces and their owners documented
> - [ ] All ingress endpoints documented
> - [ ] Database backup verification date documented
>
> **Regular drills**
> - [ ] Node failure drill (run quarterly): drain a node, verify pods reschedule
> - [ ] Backup restore drill (run quarterly): restore from backup to staging
> - [ ] Certificate expiry drill (run annually): know how to renew every cert

---

## ACT III — Ahmed's final rule

Ahmed closed his notebook. He had investigated 100 cases. He had seen every kind of technical failure. But the failures that cost the most were never purely technical.

The OOMKilled pod had been OOMKilled for three weeks before someone noticed — because there was no alert.

The expired certificate had been expired for six hours before someone called in — because the on-call rotation hadn't been updated in three months.

The wrong kubectl context had deleted a production deployment — because the developer had full admin access to production with no guard rails.

He wrote one final rule. Not a `kubectl` command. Not a YAML snippet.

*"A cluster with no owner is a ticking clock. Kubernetes is not self-healing at the organisational level. It will not page the right person when it breaks. It will not write the runbook. It will not notice when on-call has been unmanned for six months.*

*That is your job. Not the cluster's.*

*The 99 episodes before this one will happen to you — some of them, eventually, all of them. The question is not whether they happen. The question is: when they do, does the right person get woken up, know what to look at, and know what to do?*

*Answer yes to that — and no incident is a disaster."*

---

## EPILOGUE — The Complete Ahmed Archive

After 100 cases, Inspector Ahmed's rules, assembled:

| # | Rule |
|---|------|
| 1 | Pending pod = check Events. Start with `kubectl describe pod`. |
| 2 | ImagePullBackOff = check the tag in the registry, not in the manifest. |
| 3 | CrashLoopBackOff = read the logs (`--previous`). The app tells you everything. |
| 4 | Exit 137 = OOMKilled. Raise limits. Find the real cause. |
| 5 | Timeout between healthy pods = NetworkPolicy. |
| 6 | Evicted pods = disk pressure. SSH and check `du`. |
| 7 | New deploy keeps restarting = liveness probe. Add a startupProbe. |
| 8 | PVC Pending = wrong or missing StorageClass. |
| 9 | Empty Service endpoints = label mismatch. |
| 10 | Pod stuck Terminating = PID 1 ignoring SIGTERM. Fix the Dockerfile. |
| 11 | All services fail to resolve = CoreDNS down. |
| 12 | 403 from Kubernetes API = RBAC. `kubectl auth can-i` to diagnose. |
| 13 | untolerated taint = add toleration to the pod. |
| 14 | Stateful pods on spot instances = add nodeAffinity. |
| 15 | HPA shows `<unknown>` = install metrics-server. |
| 16 | 502s after every deploy = readiness probe lying. Add real checks. |
| 17 | Secret not found = wrong namespace. |
| 18 | Pod stuck in Init: = init container waiting for something that doesn't exist. |
| 19 | TLS errors = check certificate expiry. Install cert-manager. |
| 20 | Nothing being created in namespace = ResourceQuota exhausted. |
| 21 | All pods Pending everywhere = check kube-scheduler in kube-system. |
| 22 | ConfigMap updated but app uses old values = restart pods or add file watch. |
| 23 | Unexplained latency = noisy neighbour. `kubectl top pods --sort-by=cpu`. |
| 24 | Pods disappearing silently = preemption. Check PriorityClasses. |
| 25 | 502s during rolling updates = add preStop sleep 15. |
| 26 | Connection refused on healthy pod = wrong targetPort in Service. |
| 27 | Autoscaler not scaling = check cloud IAM permissions. |
| 28 | CronJob running multiple times simultaneously = set concurrencyPolicy: Forbid. |
| 29 | Ingress returns 404 for everything = no ingress controller installed. |
| 30 | StatefulSet pods can't find each other = service not headless. |
| 31 | Rolling update frozen = maxSurge and maxUnavailable both 0. |
| 32 | unauthorized on image pull = imagePullSecret expired. |
| 33 | All replicas on one node = add podAntiAffinity. |
| 34 | DB too many connections = connection leak. Use ephemeral debug containers. |
| 35 | JWT always expired = clock drift. Restart NTP. |
| 36 | Wrong cluster deleted = always verify context. Use kube-ps1. |
| 37 | connection reset by peer in service mesh = sidecar missing on one pod. |
| 38 | DaemonSet blocked by security policy = PSA namespace label misconfigured. |
| 39 | Pod fails to start = ServiceAccount doesn't exist. Create it. |
| 40 | PVC stuck Terminating = pod still mounting it. Find and delete that pod. |
| 41 | Service routing to wrong pods = selector too broad. Add version label. |
| 42 | DiskPressure but disk looks free = check inodes. `df -i`. |
| 43 | ConfigMap subPath mount not updating = subPath never updates. Accept restart. |
| 44 | Job never scheduled = requests exceed node capacity. Split the job. |
| 45 | Everything fails to create = ValidatingWebhook with dead service. |
| 46 | Slow API server = etcd on slow disk. Needs NVMe. |
| 47 | NodePort works on some nodes not others = kube-proxy crashed on that node. |
| 48 | KEDA scaling to 0 despite traffic = metrics adapter down. |
| 49 | Namespace stuck Terminating = orphaned CRs with unprocessed finalizers. |
| 50 | Can't rollback = revisionHistoryLimit: 0. Never set this. |
| 51 | Reads work, writes fail = etcd lost quorum. |
| 52 | kubectl drain blocked = PDB. Scale up first, then drain. |
| 53 | VPA fighting HPA = set VPA to Off mode. |
| 54 | Permission denied on volume = add fsGroup to securityContext. |
| 55 | Pod can't reach internet = missing egress NetworkPolicy. Don't forget DNS port 53. |
| 56 | No Prometheus metrics = wrong prometheus.io/port annotation. |
| 57 | DNS different answer on different nodes = NodeLocal cache stale. Restart DNS pod. |
| 58 | Backup jobs silently failing = alert on velero_backup_failure_total. |
| 59 | Inconsistent routing = both Ingress and HTTPRoute claim same hostname. |
| 60 | Intermittent config corruption = race condition on shared volume. Use atomic rename. |
| 61 | Operator spinning at 100% CPU = non-idempotent reconcile loop. |
| 62 | Pod creation fails with 'maximum exceeded' = LimitRange. |
| 63 | HPA scaling up and down rapidly = add scaleDown stabilization window. |
| 64 | Batch job silently failed = alert on kube_job_status_failed. |
| 65 | DaemonSet not on new nodes = node has taint DaemonSet doesn't tolerate. |
| 66 | Pods Pending due to topology spread = change to ScheduleAnyway or add zones. |
| 67 | External DNS not updating = add hostname annotation to Service. |
| 68 | KEDA ScaledObject READY=False = metrics trigger source unreachable. |
| 69 | Node NotReady at exact same time = kubelet certificate expired. |
| 70 | All pods on one node lose network = CNI agent crashed. |
| 71 | Helm upgrade fails with immutable field = never change spec.selector. |
| 72 | ArgoCD perpetually OutOfSync = add ignoreDifferences for runtime annotations. |
| 73 | Secrets readable in etcd = enable EncryptionConfiguration. |
| 74 | Control plane disk filling = audit policy logging too verbosely. |
| 75 | cert-manager Ready but old cert served = secretName mismatch. |
| 76 | Cross-zone latency = enable topology-aware routing. |
| 77 | App crashes only in first seconds = sidecar not ready. Add retry logic. |
| 78 | ExternalSecret not syncing = NetworkPolicy blocks ESO egress to Vault. |
| 79 | Pods spawning with unexpected config = MutatingWebhook injecting fields. |
| 80 | Pod 0/1 despite healthy containers = ReadinessGate condition not set. |
| 81 | CronJob never ran = too many missed starts. Set startingDeadlineSeconds. |
| 82 | Rolling update stalls = PDB minAvailable == replica count. Use maxUnavailable. |
| 83 | Resource keeps reappearing = a controller is recreating it. Stop it first. |
| 84 | Webhook 'certificate signed by unknown authority' = empty caBundle. |
| 85 | Live node declared dead = network partition blocks kubelet heartbeat. |
| 86 | 401 errors exactly N seconds after startup = cached ServiceAccount token expired. |
| 87 | Webhook TLS 'certificate is valid for X not Y' = missing SAN forms. |
| 88 | kubectl drain stuck on one pod = bare pod (no owner). Delete it manually. |
| 89 | CRD stuck deleting = Custom Resources still exist. Delete CRs first. |
| 90 | CreateContainerConfigError = missing Secret or ConfigMap in pod's namespace. |
| 91 | Cluster-wide evictions under memory pressure = BestEffort pod with no limits. |
| 92 | Batch job produces corrupt output = SIGTERM not handled gracefully. |
| 93 | Cluster network flooded with logs = log sidecar with no rate limits. |
| 94 | Namespace Terminating for days = multiple resources with orphaned finalizers. |
| 95 | DaemonSet consuming all node memory = no memory limits on logging agent. |
| 96 | Pod restarting regularly under load = liveness probe timeout too short. |
| 97 | Any pod can read production secrets = automountServiceAccountToken not disabled. |
| 98 | Half the app dies when a laptop sleeps = kubectl port-forward in production. |
| 99 | Operator breaks after cluster migration = hardcoded API server URL. |
| 100 | Nobody knows what to do during the outage = no runbook, no ownership, no on-call. |

---

*"In a hundred cases, I never found a cluster that Kubernetes had failed. I found a hundred cases where humans had misconfigured it, forgotten it, or left it without an owner. The cluster kept trying. It logged the errors. It evicted the pods. It waited for someone to read the Events.*

*The Events were always there. Were you?"*

— **Inspector Ahmed**, closing his notebook for the last time.
