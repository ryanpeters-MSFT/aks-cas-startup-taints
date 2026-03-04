# AKS startup taints and node initialization pattern

This repo demonstrates an AKS node bootstrap pattern where infrastructure logic runs before app workloads are allowed to schedule.

## Quickstart

```powershell
# invoke the script
.\setup.ps1
```

`setup.ps1` provisions infrastructure and gets kubeconfig credentials. It does not apply Kubernetes manifests.

After the cluster has been created, apply the NGINX workload and then apply the DaemonSet to initialize nodes and remove taints.

```powershell
# apply the nginx app deployment
kubectl apply -f nginx-deployment.yaml

# apply the daemonset to remove taint
kubectl apply -f startup-taint-remover.yaml
```

The script creates an AKS cluster with 1 system node. A user node pool (with 0 nodes initially) is added with Cluster Autoscaler enabled (`min=0`, `max=2`) and a taint of `startup-taint.cluster-autoscaler.kubernetes.io/testpodschedule=unavailable:NoSchedule` so sample NGINX pods are blocked until taint removal.

When `startup-taint-remover.yaml` is applied, each daemonset pod first disables `aks-node-validating-webhook` (`validatingwebhookconfiguration`) and then removes the taint from its current node with `kubectl taint nodes ...-`, allowing pending NGINX workloads to schedule.

## Current Setup Behavior

The current `setup.ps1` uses `--node-taints` on the user node pool. It does not currently configure Workload Identity, and it does not use `--node-init-taints` in the active script.

## What Are Startup Taints?

A `startup-taint` is a node taint applied when a node joins the cluster. The taint blocks normal workloads (for example with `NoSchedule`) until an initialization workflow clears it.

In AKS, this is useful when new nodes need host-level preparation (agents, config, mounts, security hardening, etc.) before application pods can safely run.

## How Does This Work With The Cluster Autoscaler?

When a workload is pending and targets a pool that can scale from `0`, Cluster Autoscaler (CAS) can still plan scale-up if it understands the startup taint behavior.

The startup taint pattern enables this flow:

1. CAS detects unschedulable workload.
2. CAS scales the node pool from `0`.
3. New node joins with startup taint.
4. A daemonset tolerating the startup taint runs first and performs node initialization.
5. The daemonset removes the startup taint.
6. Application workloads are now schedulable.

This prevents application pods from racing node bootstrap while still allowing scale-from-zero.

Essentially, the startup taint behavior prevents untolerable workloads from deploying, but still allow the CAS to configure a scale-up plan when workloads are pending. 

## Example scenario

A practical pattern is:

- Add startup taint on the user pool (for example `startup-taint.cluster-autoscaler.kubernetes.io/testpodschedule=unavailable:NoSchedule`).
- Deploy a daemonset that tolerates that taint.
- In the daemonset, run initialization scripts (install/configure dependencies, fetch runtime config, validate readiness).
- Remove the startup taint when initialization is complete.
- Application deployment (for example `nginx`) schedules only after initialization.

## References

- [AKS node taints (including startup taints)](https://learn.microsoft.com/en-us/azure/aks/use-node-taints#use-node-initialization-taints-preview)
- [Cluster Autoscaler FAQ](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#what-are-the-parameters-to-ca)
- [AKS Cluster Autoscaler overview](https://learn.microsoft.com/en-us/azure/aks/cluster-autoscaler)
- [Kubernetes taints and tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
