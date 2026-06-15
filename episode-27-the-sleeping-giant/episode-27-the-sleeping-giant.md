# Episode 27 — "The Sleeping Giant"
### *Inspector Ahmed and the cluster that runs out of nodes*

**Culprit:** Cluster autoscaler not scaling up — missing IAM permissions
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `cluster-autoscaler` `autoscaling` `nodes` `iam` `cloud`

---

## OPENING — Crime scene

"Pods Pending. Cluster Autoscaler supposedly configured. But no new nodes appearing. The autoscaler was awake — but its hands were tied."

```bash
kubectl get pods --all-namespaces | grep Pending | wc -l
```

```
12
```

```bash
kubectl describe pod api-7f9d4b-xk2p -n production
```

```
Events:
  Warning  FailedScheduling  5m  default-scheduler
    0/3 nodes available: 3 Insufficient cpu.
```

Not enough CPU. The cluster should scale up. It's not.

---

## ACT I — Checking the autoscaler

```bash
kubectl logs deployment/cluster-autoscaler -n kube-system | tail -30
```

```
I0314 10:22:14.000000  1 scale_up.go:468] Scale-up: setting group
  eks-nodegroup-7f9d4b to 4
E0314 10:22:15.000000  1 aws_manager.go:313] Failed to set ASG size:
  AccessDeniedException: User: arn:aws:iam::123456789:role/cluster-autoscaler-role
  is not authorized to perform: autoscaling:SetDesiredCapacity
  on resource: arn:aws:autoscaling:eu-west-1:123456789:autoScalingGroup:*
```

The autoscaler knows it needs to scale up. It's trying. But the IAM role it's using doesn't have permission to call `autoscaling:SetDesiredCapacity` on the Auto Scaling Group.

> **📚 Teaching moment — Cluster Autoscaler on AWS/EKS**
>
> The Cluster Autoscaler runs as a pod in `kube-system` and manages the cloud provider's node groups (ASGs on AWS, MIGs on GCP, VMSSs on Azure). To add or remove nodes, it calls cloud provider APIs.
>
> On EKS, the autoscaler pod needs an IAM role (via IRSA — IAM Roles for Service Accounts) with specific permissions:
> - `autoscaling:DescribeAutoScalingGroups`
> - `autoscaling:SetDesiredCapacity`
> - `autoscaling:TerminateInstanceInAutoScalingGroup`
> - `ec2:DescribeLaunchTemplateVersions`
>
> Missing any of these = autoscaler watches but can't act.

---

## ACT II — Fixing the IAM policy

Ahmed adds the missing permissions to the IAM role:

```json
{
  "Effect": "Allow",
  "Action": [
    "autoscaling:SetDesiredCapacity",
    "autoscaling:TerminateInstanceInAutoScalingGroup"
  ],
  "Resource": "*"
}
```

```bash
kubectl rollout restart deployment/cluster-autoscaler -n kube-system
kubectl logs deployment/cluster-autoscaler -n kube-system -f | grep "Scale-up"
```

```
I0314 10:25:44.000000  1 scale_up.go:468] Scale-up: setting group
  eks-nodegroup-7f9d4b to 4
I0314 10:25:45.000000  1 scale_up.go:501] Scale-up: group
  eks-nodegroup-7f9d4b size set to 4
```

New node joins the cluster within 3 minutes. Pending pods are scheduled.

---

## EPILOGUE

*"The autoscaler logs tell you exactly why it's not scaling. It's almost always IAM permissions on AWS, or a misconfigured node group annotation. Check the logs before assuming the autoscaler is broken."*

> **Inspector Ahmed's Rule #27:** Cluster not scaling up despite Pending pods? Read the cluster-autoscaler logs. The reason is always there. On AWS: check IAM. On GCP: check service account. On Azure: check managed identity.
