Anthos Config Management Samples 
============

This repository contains samples for [Anthos Config Management][1].

## Examples

### [Quickstart](quickstart/)

A single clsuter example showing how to sync configurations from git using
Config Sync. This includes examples for both [multi-repo mode](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/how-to/multi-repo)
and the legacy mode.

### [Foo-Corp](foo-corp/)

A single cluster example showing several features of Anthos Config Management
working together.

### [Hello, Namespace!](hello-namespace/)

A simple example to generalize how to define and enforce configuration.

### [Locality-Specific Policy](locality-specific-policy/)

Configure policy to apply only to resources in specific regions.

### [CI Pipeline](ci-pipeline/)

Create a CloudBuild CI pipeline on a structured config directory.

### [Unstructured CI Pipeline](ci-pipeline-unstructured/)

Create a CloudBuild CI pipeline on an unstructured directory.

### [Application Pipeline](ci-app/)

Validate your application against company policies.

## CRDs

### [ConfigManagement](crds/)

The ConfigManagement CRD is used to install Anthos Config Management.

[1]: https://cloud.google.com/anthos-config-management/
[2]: https://cloud.google.com/anthos-config-management/docs/overview/
