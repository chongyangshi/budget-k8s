# Budget Kubernetes for personal projects

This project is a template for creating a low-budget, managed Kubernetes environment for running personal projects on Google Cloud Platform (GCP), while trading off as little in security and reliability as possible.

## What's in the box

* A **Virtual Private Cloud (VPC) network**, pre-configured in a reasonably locked down manner, but not obstructively so;
* A **managed Kubernetes cluster** using Google Kuberenetes Engine (GKE), with best security practices (those not significantly elevating the personal project cost) configured out-of-box, on zonal mode with no cluster management cost;
* A self-contained Google Compute Engine (GCE) **virtual machine for ingress load-balancing** using [Traefik Proxy](https://doc.traefik.io/traefik/), to avoid the high standing cost of GCP Load Balancers;
* A pre-configured Google Container Registry (GCR) for storing private container images accessible from the cluster;
* Pre-configured managed KMS encryption for all persistent disks and Kubernetes Secrets.

For more details on the various cost-saving measures made possible within the context of personal projects, see [this blogpost (WIP)](http:///) for more details.

As long as you are willing to expose your ingress traffic to a CDN, you should use one of the [CDN providers that is part of GCP's CDN Interconnect scheme](https://cloud.google.com/network-connectivity/docs/cdn-interconnect) (such as Cloudflare) to front as much internet traffic reaching your cluster ingress as possible. This way you will pay for most return egress traffic at a discounted rate.

## Setting up

### Preparation

This template uses Terraform v1.0+, which is now generally available at the time of writing. It may still work with earlier versions of Terraform. It is recommended that you start a fresh GCP project for applying Terraform configurations from this template, in order to potential unexpected conflicts and data loss.

1. Run `gcloud auth login` and `gcloud auth application-default login` first to configure your local command line credentials, if not yet done for your project. 

2. You will also need to have enabled the following APIs for the project, which might take a few minutes:

```bash
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable cloudkms.googleapis.com
```

3. Due to the classic chicken-and-egg problem in Terraform, you then need to create a Terraform state bucket in Google Cloud Storage manually, and set up versioning for it (in case of a screw up later), before you can apply any Terraform configurations:

```bash
gsutil mb -l EU -c STANDARD -b on gs://my-project-id-terraform-state
gsutil versioning set on gs://my-project-id-terraform-state
```

Note down the name you've chosen for your project's remote state bucket (e.g. `my-project-id-terraform-state`), as you will need it for the backend config below.

Because Terraform remote state should not be used for storing any sensitive secrets, customer-managed key encryption will not yet be configured for this bucket. Instead the Google-managed transparent encryption key is used. If desired, you can Terraform an appropriate KMS key ring and customer-managed crypto key, and add this with `gsutil kms`, once everything has has been applied into your GCP project.

4. You will also need to tell Terraform about the backend storage bucket you've created earlier. To do this, you can either:

* [Pass a `backend-config` file to your terraform commands](https://www.terraform.io/docs/language/settings/backends/configuration.html#partial-configuration)
* Add your your state storage bucket name into Terraform, after renaming `backend.tf.example` to `backend.tf` under the following directories:
  * `terraform/base`
  * `terraform/ingess`

### Configuration

You can configure your project with `terraform/terraform.tfvars`. See `terraform/variables.tf` for more details on the configuration variables, as well as other options you can configure.

### Spinning up the infrastructure setup

This project uses two different providers:

* `hashicorp/google` (and associated `hashicorp/google-beta`) for GCP resources
* `hashicorp/kubernetes` for in-cluster configurations of the ingress Traefik Proxy and associated GCP resources

Becaus the `kubernetes` provider cannot be configured properly until the `google` provider has created the actual GKE Kubernetes cluster -- a dependency between the two providers -- it is somewhat necessary for the template to be split in two layers so that they could be bootstrapped cleanly.

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

Traefik implements its Kubernetes TLS secret controller with Reflection, as a result it requires the ability to list all secrets in all namespaces it watches for new ingress resources in by default, and [stubbornly refuses](https://github.com/traefik/traefik/issues/7097) to provide a config option to turn off the code rquiring secret access, even if the user does not want to load any TLS certificates.

We therefore have had to set up a namespace dedicated to services exposed via Traefik, which is the only namespace Traefik is configured to be able to read all secrets in. This namespace is **`ingress`**. You should only run the services directly terminating ingress traffic in this namespace. The manifests for such a service looks like the following:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
  namespace: ingress
spec:
  selector:
    matchLabels:
      app: nginx-test
  replicas: 2 
  template:
    metadata:
      labels:
        app: nginx-test
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-test
  namespace: ingress
spec:
  selector:
    app: nginx-test
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-test
  namespace: ingress
  annotations:
    kubernetes.io/ingress.class: "traefik"
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.tls.certresolver: default
    traefik.ingress.kubernetes.io/router.tls.domains.0.main: "your-domain.example.com"
spec:
  rules:
  - host: your-domain.example.com
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: nginx-test
            port:
              number: 80
```

In the above example:

* We have an ingress-terminating Deployment called `nginx-test` set up with 2 replicas in the `ingress` namespace, which serves plain-text traffic on TCP 80;
* A corresponding `nginx-test` Service resource, which tells Kubernetes to forward terminating traffic to the Deployment's replicas;
* A corresponding `nginx-test` Ingress resource, which tells Traefik Proxy (running on the ingress load-balancing GCE instance) to set up TLS termination for our hostname `your-domain.example.com`, and then send traffic for that domain to be terminated by the `nginx-test` Service in plain-text.

## Estimated cost of upkeep

WIP

## Disclaimer

This template is made available through the MIT License, with full terms available in `LICENSE` of this repository. Cost estimations are based on the author's best-effort understanding of the GCP pricing system at the time of writing. GCP may also choose to change any part of their pricing system at any time. The author is not liable for any discrepancies between the estimations and actual bills when using this template, however caused.