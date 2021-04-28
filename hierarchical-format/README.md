# Config Sync Hierarchical Root Repository Example - Basic Cluster Configuration

This example shows how a cluster admin can use a Config Sync hierarchical root repository to manage the configuration of a
Kubernetes cluster shared by two different teams, `team-1` and `team-2`.
The cluster configuration is under the `config/` directory.

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
