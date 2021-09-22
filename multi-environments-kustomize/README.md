#  Using ConfigSync with Multiple Environments

This guide shows you how to set up Config Sync for GKE across two environments using config management best practices.

This example provides two different ways of rendering and syncing your configurations
- **external rendering**:
  This option requires you to set up two additional GitHub repos for the rendered configs, `foo-config-dev`, and `foo-config-prod`.
  It also requires setting up a Cloud Build pipeline to render the source configs, and push the rendered configs to the aforementioned GitHub repos.
  Each cluster will be configured to sync from one of the rendered repo.
- **automated rendering**:
  Config Sync support automated rendering in versions 1.9.0 or later.
  You can check in the Kustomize configurations to your Git repository,
  and Config Sync will render and sync them to your clusters.

## Overview

In this scenario, you're part of a platform admin team at Foo Corp.
The Foo Corp applications are deployed to GKE, with resources divided across two projects, `dev` and `prod`.
The `dev` project contains a development GKE cluster, and the `prod` project contains the production GKE cluster.
Your goal as the platform admin is to ensure that both environments stay within compliance of Foo Corp's policies,
and that base level resources - like Kubernetes namespaces and service accounts- remain consistent across both environments. 
