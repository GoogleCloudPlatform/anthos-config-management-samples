# Config Sync Hierarchical Root Repository Example - Basic Cluster Configuration

This example shows how a cluster admin can use a Config Sync hierarchical root repository to manage the configuration of a
Kubernetes cluster shared by two different teams, `team-1` and `team-2`.
The cluster configuration is under the `config/` directory.

## Before you begin

- You’ll need a cluster that has Config Sync installed.
  Please follow the [instructions](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/how-to/installing)
  to install Config Sync if it is not set up yet.
- [Install the `nomos` command](https://cloud.devsite.corp.google.com/kubernetes-engine/docs/add-on/config-sync/how-to/nomos-command#installing)


To use the Config Sync in the mono-repo mode, the cluster admin should first
install the Config Sync Operator, and then run:
```
kubectl apply -f config-management-mono-repo-mode.yaml
```

To use the Config Sync in the multi-repo mode (CSMR), the cluster admin should first
install the Config Sync Operator, and then run:
```
kubectl apply -f config-management-multi-repo-mode.yaml
kubectl apply -f rootsync.yaml
```
