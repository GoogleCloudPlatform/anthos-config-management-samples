Anthos Config Management Samples 
============

This repository contains samples for [Anthos Config Management][1].

## Examples 

### [Quickstart](quickstart/)

A single-cluster example showing how to sync configurations from git using
Config Sync. This includes examples for both [multi-repo mode](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/how-to/multi-repo)
and the legacy mode.

### [Foo-Corp](foo-corp/)

A single cluster example showing several features of Anthos Config Management
working together.

### [Hello, Namespace!](hello-namespace/)

A simple example to generalize how to define and enforce configuration.

### [Using Hierarchical Repos with Config Sync](hierarchical-format/)

Demonstrates how to set up a hierarchical repository for Config Sync.

### [Locality-Specific Policy](locality-specific-policy/)

Configure policy to apply only to resources in specific regions.

### [Namespace Inheritance](namespace-inheritance/) 

Shows how to use namespace inheritance with a Config Sync hierarchical repo. 

### [Rendering Configs with Kustomize](kustomize-pipeline/)

Demonstrates how to use Kustomize and Cloud Build to prepare configs for deployment with Config Sync.

### [CI Pipeline](ci-pipeline/)

Create a CloudBuild CI pipeline on a structured config directory.

### [Unstructured CI Pipeline](ci-pipeline-unstructured/)

Create a CloudBuild CI pipeline on an unstructured directory.

### [Application Pipeline](ci-app/)

Validate your application against company policies.

### [Deploying a Helm Chart with ConfigSync](helm-component/)

Demonstrates how to use Config Sync to sync a rendered Helm Chart. 

### [Multi-Cluster Anthos Config Management Setup](multi-cluster-acm-setup/)

Deploy multiple GKE clusters and install Anthos Config Management on them.

### [Multi-Cluster Fan-out](multi-cluster-fan-out/)

Manage identical Namespaces, RoleBindings, and ResourceQuotas across multiple GKE clusters using Anthos Config Management and GitOps.

### [Multi-Cluster Access and Quota](multi-cluster-access-and-quota/)

Manage cluster-specific and namespace-specific Namespaces, RoleBindings, and ResourceQuotas across multiple clusters using Anthos Config Management, GitOps, and Kustomize.

### [Multi-Cluster Ingress](multi-cluster-ingress/)

Manage an application with Multi-Cluster Ingress using Anthos Config Management, GitOps, and Kustomize.

### [Multi-cluster + Multiple Environments with Kustomize](multi-environments-kustomize/) 

Manage an application spanning multiple GCP projects, across dev and prod environments, with Config Sync, Kustomize, and Cloud Build. 

### [Namespace-specific policy](namespace-specific-policy/)

Configure namespace specific policies such as Role, RoleBinding and
NetworkPolicy.

## CRDs

### [ConfigManagement](crds/)

The ConfigManagement CRD is used to install Anthos Config Management.

[1]: https://cloud.google.com/anthos-config-management/
[2]: https://cloud.google.com/anthos-config-management/docs/overview/
