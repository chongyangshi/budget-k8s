# Budget K8s

This project provides a template for creating a reasonably-secured GCP managed Kubernetes environment for running personal projects on a budget.

## Bootstrap

Run `gcloud auth login` and `gcloud auth application-default login` to configure your local command line credentials if you've not yet done it for your project.

This project uses Terraform v1.0+, which is now generally available at the time of writing. It may still work with earlier versions of Terraform.

Before we can terraform anything, by the law of avian-and-egg, we must create a Terraform state bucket in Google Cloud Storage manually, and set up versioning for it (in case we screw up later). 

```bash
gsutil mb -l EU -c STANDARD -b on gs://my-project-id-terraform-state
gsutil versioning set on gs://my-project-id-terraform-state
```

Because we should not rely on Terraform state for storing any secrets, server-side encryption will not yet be configured for this bucket. You can Terraform an appropriate KMS key ring and crypto key and add this with `gsutil encryption` later if desired.

Once the storage bucket is bootstrapped, configure your project settings. Use `terraform.tfvars.example` under `terraform/` as an example, renaming it `terraform.tfvars` which will not be committed to this repo. You will also need the name of the state storage bucket you just chose for `state_bucket_name`.

See `terraform/variables.tf` for more details on the input variable options.

You will also need to config backend storage, which you can either [pass a `backend-config` file to your terraform commands](https://www.terraform.io/docs/language/settings/backends/configuration.html#partial-configuration) or by renaming `backend.tf.example` under `terraform/` to `backend.tf` and put your state storage bucket name in.

You can then do the usual:

```bash
cd terraform
terraform init
terraform apply
```

## Usage

WIP