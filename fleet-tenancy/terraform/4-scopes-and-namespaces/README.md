# Configure fleet scopes and namespaces

The Terraform configurations in this directory sets up fleet scopes and namespaces.

## Usage

See the [variable definitions file] for an exhaustive list of variables.
These can be provided as [command line variables] at runtime.

For example:
```shell
export TF_VAR_project=your-gcp-project
export TF_VAR_sa_key_file=path/to/your-sa-key-file
terraform init
terraform plan
terraform apply
```

[variable definitions file]: ./variables.tf
