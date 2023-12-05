# Set up your fleet

The Terraform configurations in this directory sets up a fleet, along with the a list of enabled API services, and a service account that Terraform can use to access the Google Cloud APIs.

## Usage

See the [variable definitions file] for an exhaustive list of variables.
These can be provided as [command line variables] at runtime.

For example:
```shell
export TF_VAR_project=your-gcp-project
export TF_VAR_gcp_sa_id=fleet-team-admin
export TF_VAR_gcp_sa_display_name=fleet-team-admin
export TF_VAR_gcp_sa_description="A GCP service account that Terraform can use to access the Google Cloud APIs"
terraform init
terraform plan
terraform apply
```

[variable definitions file]: ./variables.tf
