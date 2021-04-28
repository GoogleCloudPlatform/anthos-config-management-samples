The directory (which is not required for using Config Sync) contains the output of `nomos hydrate`, which compiles
the configs under the `cluster/`, `namespaces/`, `system/` directories to the exact form that would be sent to the APIServer to apply.
The cluster-scoped resources are under this directory directly. Each
subdirectory includes all the configs for the
resources under a namespace. 

```
.
├── clusterrolebinding_namespace-reader.yaml
├── clusterrole_namespace-reader.yaml
├── clusterrole_secret-admin.yaml
├── clusterrole_secret-reader.yaml
├── customresourcedefinition_crontabs.stable.example.com.yaml
├── namespace_team-1.yaml
├── namespace_team-2.yaml
├── team-1
│   ├── crontab_my-new-cron-object.yaml
│   ├── limitrange_limits.yaml
│   ├── networkpolicy_default-deny-egress.yaml
│   ├── resourcequota_pvc.yaml
│   ├── rolebinding_secret-reader.yaml
│   └── serviceaccount_sa.yaml
└── team-2
    ├── crontab_my-new-cron-object.yaml
    ├── limitrange_limits.yaml
    ├── networkpolicy_default-deny-all.yaml
    ├── resourcequota_pvc.yaml
    ├── rolebinding_secret-admin.yaml
    └── serviceaccount_sa.yaml
```

