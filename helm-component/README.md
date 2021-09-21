This example provides two different ways of rendering and syncing your configurations
- [manual rendering](manual-rendering/README.md):
  this option requires you to render the configurations using the Helm CLI manually,
  and check in the rendered configurations to your Git repository.
  Config Sync will sync from the rendered output directly.
- [automated rendering](automated-rendering/README.md):
  Config Sync supports rendering Kustomize configurations and Helm Charts in version 1.9.0 or later.
  You can check in the Kustomize configurations and Helm charts to your Git repository,
  and Config Sync will render and sync them to your clusters.