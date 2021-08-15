# CHANGEME: set this to your GCP project ID (not the display name, which may be different)
project_id = "my-budget-k8s"

# CHANGEME: set these to the GCP region and availability zone in which you want to run this setup
# Available regions and zones in https://cloud.google.com/compute/docs/regions-zones
project_region = "us-west1"
cluster_zone   = "a"

# CHANGEME: set this to a region suitable for storing your custom container images which the cluster will be able to access
# Available locations in https://cloud.google.com/storage/docs/locations#available-locations
container_registry_region = "US"

# If you require ingress into other TCP or UDP ports from the internet, change the list below
external_ingress_tcp_ports = ["80", "443"]
external_ingress_udp_ports = []

# CHANGEME: set this to your home or VPN network range for accessing your cluster control plane remotely
external_control_plane_access_ranges = ["12.34.56.78/32"]

# Adjust the instance types and counts for the two node pools to provision different worker nodes.
# See here for lists of spec and pricing: https://cloud.google.com/compute/vm-instance-pricing
node_pools_first_instance_type   = "n2-standard-2"
node_pools_first_instance_count  = 2
node_pools_second_instance_type  = "n2-standard-4"
node_pools_second_instance_count = 1

# CHANGEME: set this to an email you want to use for registering with Let's Encrypt, so that Traefik will be able
# to request ACME TLS certificates on your behalf. Certificate expiration remainders will be sent here.
ingress_acme_account_email = "you@example.com"
