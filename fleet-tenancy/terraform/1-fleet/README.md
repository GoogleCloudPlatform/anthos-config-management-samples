# Set up your fleet

The Terraform configurations in this directory sets up a fleet, along with the a list of enabled API services, and a service account that Terraform can use to access the Google Cloud APIs.

## Usage

See the [variable definitions file] for an exhaustive list of variables.
These can be provided as [command line variables] at runtime.

For example:
```shell
export TF_VAR_project=<Your GCP project ID where a Fleet will be created>
terraform init
terraform plan
terraform apply
```

[variable definitions file]: ./variables.tf
[command line variables]: https://www.terraform.io/language/values/variables#variables-on-the-command-line
