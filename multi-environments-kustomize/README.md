#  Using ConfigSync with Multiple Environments

This guide shows you how to set up Config Sync for GKE across two environments using config management best practices.

This example provides two different ways of rendering and syncing your configurations:
- **[Config Sync Rendering](config-sync-rendering)**:
 
  Config Sync support automated rendering in versions 1.9.0 or later.
  
  You can check in the Kustomize configurations to your Git repository,
  and Config Sync will render and sync them to your clusters.
  
  Please see https://cloud.google.com/anthos-config-management/docs/tutorials/multiple-environments-config-sync to get started.
  
- **[Cloud Build Rendering](cloud-build-rendering)**:
  
  This option requires you to set up two additional GitHub repos for the rendered configs, `foo-config-dev`, and `foo-config-prod`.

  It also requires setting up a Cloud Build pipeline to render the source configs, and push the rendered configs to the aforementioned GitHub repos.

  Each cluster will be configured to sync from one of the rendered repo.

  Please see https://cloud.google.com/anthos-config-management/docs/tutorials/multiple-environments-cloud-build to get started. 
