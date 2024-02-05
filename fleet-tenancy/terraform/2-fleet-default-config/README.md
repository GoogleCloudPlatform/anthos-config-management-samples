# Configure Fleet Default Member Config

The Terraform configurations in this directory configures the fleet default member config for Config Management

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
[command line variables]: https://www.terraform.io/language/values/variables#variables-on-the-command-line