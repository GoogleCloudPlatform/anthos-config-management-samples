# Anthos Service Mesh (ASM) and Anthos Config Management (ACM) tutorial

This folder contains the resources for the tutorial: Strengthen your app’s security with Anthos Service Mesh (ASM) and Anthos Config Management (ACM). This tutorial shows you how to leverage ACM’s Policy Controller and Config Sync on a Google Kubernetes Engine (GKE) cluster. You deploy a sample app and then improve the app’s security posture by applying some `Constraints` of the ASM policy bundle.

The `online-boutique` folder allows to deploy the Online Boutique sample apps via Kustomize with associated `ServiceAccounts` and `AuthorizationPolicies`.

The `root-sync` contains the folders representing the different steps of the tutorial:
1. `init` - install ASM and set up the `online-boutique` `RepoSync`
2. `deployments` - deploy the `ingress-gateway` and the `onlineboutique` namespaces and apps
3. `enforce-sidecar-injection` - deploy policies to enforce the sidecar injection for `Namespace` and `Pod`
4. `enforce-strict-mtls` - deploy policies to enforce `STRICT` mTLS for the entire Mesh and for any `PeerAuthentication`
5. `fix-strict-mtls` - deploy the default `STRICT` mTLS `PeerAuthentication` in the `istio-system` namespace
6. `enforce-authorization-policies` - deploy policies to enforce the default `deny` `AuthorizationPolicy` for the entire Mesh
7. `fix-default-deny-authorization-policy` - deploy the default `deny` `AuthorizationPolicy` in the `istio-system` namespace
8. `deploy-authorization-policies` - deploy the fine granular `AuthorizationPolicy` resources in order to make the Online Boutique sample apps work
