# Budget Kubernetes for personal projects

This project is a template for creating a low-budget, managed Kubernetes environment for running personal projects on Google Cloud Platform (GCP), while trading off as little in security and reliability as possible. This currently provides a cluster with 8 CPU cores and 16GB of memory for under £50 a month (VAT included).

## What's in the box

* A **Virtual Private Cloud (VPC) network**, pre-configured in a reasonably locked down manner, but not obstructively so;
* A **managed Kubernetes cluster** using Google Kuberenetes Engine (GKE), with best security practices (those not significantly elevating the personal project cost) pre-configured out-of-box, on zonal mode with no cluster management cost;
* A self-contained Google Compute Engine (GCE) **virtual machine for ingress load-balancing** using [Traefik Proxy](https://doc.traefik.io/traefik/), to avoid the high standing cost of GCP Load Balancers;
* Wrapper module for quickly creating ingress endpoints for each hostname of services you wish to expose on the internet;
* A pre-configured Google Artifact Registry (GCR) for storing private container images accessible from the cluster;
* Pre-configured managed KMS encryption for all persistent disks and Kubernetes Secrets.

For more details on the various cost-saving measures made possible within the context of personal projects, see [this blog post](https://blog.scy.email/managed-kubernetes-on-a-hobbyist-budget.html) for more details.

As long as you are willing to expose your ingress traffic to a CDN, you should use one of the [CDN providers that is part of GCP's CDN Interconnect scheme](https://cloud.google.com/network-connectivity/docs/cdn-interconnect) (such as Cloudflare) to front as much internet traffic reaching your cluster ingress as possible. This way you will pay for most return egress traffic at a discounted rate.

## Setting up

### Preparation

This template uses Terraform v1.0+, which is now generally available at the time of writing. It may still work with earlier versions of Terraform. It is recommended that you start a fresh GCP project for applying Terraform configurations from this template, in order to avoid unexpected conflicts and data loss.

1. Run `gcloud auth login` and `gcloud auth application-default login` first to configure your local command line credentials, if not yet done for your project. 

2. You will also need to have enabled the following APIs for the project, which might take a few minutes:

```bash
gcloud services enable artifactregistry.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable cloudkms.googleapis.com
```

3. Due to the classic chicken-and-egg problem in Terraform, before you can apply any actual Terraform configurations, you need to create a Terraform state bucket in Google Cloud Storage manually, and set up versioning for it (in case of a screw-up later):

```bash
gsutil mb -l EU -c STANDARD -b on gs://my-project-id-terraform-state
gsutil versioning set on gs://my-project-id-terraform-state
```

Note down the name you've chosen for your project's remote state bucket (e.g. `my-project-id-terraform-state`), as you will need it for the backend config below.

Because Terraform remote state should not be used for storing any sensitive secrets, customer-managed key encryption will not yet be configured for this bucket. Instead the Google-managed transparent encryption key is used. If desired, you can Terraform an appropriate KMS key ring and customer-managed crypto key, and add this with `gsutil kms`, once everything has has been applied into your GCP project.

4. You will also need to tell Terraform about the backend storage bucket you've created above. To do this, you can should add your state storage bucket name into Terraform, after renaming `backend.tf.example` to `backend.tf` under the following directories:

* `terraform/base`
* `terraform/ingess`

5. Not essential, but it is recommended that you also request a preemptible instance limit by "Editing" the right value in the GCP `Quotas` panel, for the region you will run your cluster in, for example:

![image](https://user-images.githubusercontent.com/8771937/142948710-63f92c5b-c280-4d43-adf8-c990489fc305.png)

This may not be possible without upgrading to a paid billing account. I've observed that the regular CPU regional quotas for each instance CPU type like `N2_CPUS` or `N2D_CPUS` don't always reset correctly after GCP terminates preemptible instances, which are used by this infrastructure template. They occasionally cause "ghost" usages of the quota preventing your cluster from fully scaling up. From trial-and-error it seems that the special preemptible quotas reset more consistently than the regular quota.

### Configuration

You can configure your project with `terraform/terraform.tfvars`. See `terraform/variables.tf` for more details on the configuration variables, as well as other options you can configure.

### Spinning up the infrastructure setup

This project uses two different providers:

* `hashicorp/google` (and associated `hashicorp/google-beta`) for GCP resources
* `hashicorp/kubernetes` for in-cluster configurations of the ingress Traefik Proxy and associated GCP resources

Because the `kubernetes` provider cannot be configured fully until the `google` provider has created the actual GKE cluster -- a dependency between the two providers -- it is somewhat necessary for the template to be split in two layers so that they could be bootstrapped cleanly.

Therefore, you should execute the standard Terraform apply process below in the following order:

* `terraform/base`
* `terraform/ingess`

```bash
cd terraform/base
terraform init
terraform apply

cd ../../terraform/ingress
terraform init
terraform apply
```

## Usage

Traefik implements its Kubernetes TLS secret controller with Reflection, as a result it requires the ability to list all secrets in all namespaces it watches for new ingress resources in by default, and [stubbornly refuses](https://github.com/traefik/traefik/issues/7097) to provide a config option to turn off the code requiring secret access, even if the user does not want to load any TLS certificates (as is in our case using Let's Encrypt ACME instead).

We therefore have had to set up a namespace dedicated to services that will be exposed via Traefik, and ensure that namespace is the only one in which Traefik is configured to be able to read all secrets. This namespace is called **`ingress`** and is configured by the `terraform/ingress` layer. 

For backend services which don't need secrets to run, or whose secrets are not sensitive enough and we don't need to worry about them if Traefik is compromised, they could run in the `ingress` namespace itself. Any service with sufficiently sensitive secrets should run in a namespace in which Traefik has no access to secrets. But since Traefik will then refuse to forward traffic into these namespaces, we will need to setup a light-weight service proxy for each such backend service in the `ingress` namespace using NGINX.

The entire process of configuring ingress for each backend service, whether running in the `ingress` namespace or another, has been streamlined in this template via the `terraform/ingress/service_proxy` module. 

```tf
module "service_nginx_example" {
  source = "./service_proxy"

  service_hostnames = ["example.com", "www.example.com"]
  service_name      = "nginx-example"
  service_port      = 80
  service_namespace = "default"

  traefik_terminate_tls = true
}
```

See `terraform/ingress/gke_ingresses.tf.example` for more details.

By default traffic between Kubernetes namespaces are not restricted, so in the above example, the service proxy Pods created automatically in the `ingress` namespace could then reverse proxy traffic it receives from Traefik, to an `nginx-example` Pod running in the `default` namespace. It is recommended however that you set up [ingress network policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) to allow only the service proxy pods (which will always carry the Pod label `component: "service-proxy"`) to reach those backend applications across namespaces.

### Middlewares and other custom Traefik configurations

A special template file under `terraform/ingress/instance_resources/middlewares.yaml` has been created to host custom [middleware configurations](https://doc.traefik.io/traefik/middlewares/overview/), which are built-in Traefik extensions which perform custom request handling behaviours such as passing Proxy Protocol headers or performing basic HTTP auth. Two such examples are present in this file: `testBasicAuth` and `testProxyProtocolHeader`.

This file can also hold other [custom configurations](https://doc.traefik.io/traefik/reference/dynamic-configuration/file/) for Traefik. This file is loaded into the runtime when the ingress load-balancing instance is started.

Once the template file has has been re-applied via Terraform and the ingress load-balancing instance restarted automatically in the process, middlewares can be loaded for each Ingress object by passing a list of their names with `@file` suffixes into the `service_traefik_middlewares` variable, as shown in the example from the previous section.

## Estimated cost of upkeep

The following typical daily costs were billed by Google Cloud Platform running my 3-node cluster in an availability zone of the `europe-west-2` (London) region, comprising of a first preemptible node pool of two  `n2-custom-2-4096` instances and a second preemptible node pool of one `n2-custom-4-8192` instance:

| Service                                         | Daily Cost (£) | 30-Day Extrapolation (£)  |
| ----------------------------------------------- | -------------- | ------------------------- |
| GCE N2 VM Worker Nodes Preemptible CPU and RAM  | 0.71           | 21.30                     |
| GCE VM Standard Disk & ~70GB of K8s PV Disk     | 0.27           |  8.10                     |
| GCE E2 Ingress VM Persistent CPU and RAM        | 0.20           |  6.00                     |
| KMS Software Cryptographic Operations           | 0.03           |  0.60                     |
| NAT Gateway Uptime and Data Processing          | 0.09           |  2.70                     |
| KMS Active Symmetric Key Versions               | <0.01          |  0.10                     |
| Network Egress via Carrier Peering (Cloudflare) | ≈0.01          |  0.36 (10 GB at 0.036/GB) |
| **total**                                       | **1.32**       | **39.20**                 |
| UK VAT (20%)                                    |                |  7.84                     |
| **bill sum**                                    |                | **47.04**                 |

<sup>*</sup> _Cost items such as VM-initiated network egress, Google Artifact Registry and static IP charge which are individually too small to register on the BigQuery billing export data._

The total usable computing resources covered by these costs is around 8 vCPUs and 16 GB of RAM a month, minus overhead consumed by cluster components.

## Disclaimer

This template is made available under the MIT License, full terms of which can be found in the `LICENSE` file within this repository. 

Cost estimations are based on the author's best-effort understanding of the GCP pricing system at the time of writing. GCP may also choose to change any part of their pricing system at any time. The author is not liable for any discrepancies between the estimations and actual bills when using this template, however caused.

Update late-2022: since originally publishing this repository, I have started working for [DeepMind](https://deepmind.com), which is part of Alphabet Inc. All technical information in this repository are based on publicly-available information. Nothing in this repository reflects the view or endorsement of DeepMind, Google, or Alphabet Inc.