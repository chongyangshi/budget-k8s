# CHANGEME: set this to your GCP project ID (not the display name, which may be different)
project_id = "my-budget-k8s"

# CHANGEME: set these to the GCP region and availability zone in which you want to run this setup
# Available regions and zones in https://cloud.google.com/compute/docs/regions-zones
project_region = "us-west1"
cluster_zone   = "a"

# We disable cluster container logs in Cloud Logging, as they can easily exceed the 50GB monthly
# free tier and incur charges. You can still look up container logs using kubectl logs. But if
# you would prefer to ingest these logs, change the following to true.
cluster_container_logs_ingested = false

# If you require ingress into other TCP or UDP ports from the internet, change the list below
external_ingress_tcp_ports = ["80", "443"]
external_ingress_udp_ports = []

# The following only need to be set if you intend to run service Pods in the `ingress` namespace directly,
# which allows Pods to accept traffic forwarded by Traefik Proxy directly without a service proxy in the
# middle. This will result in any Secrets they need access to be accessible by Traefik, which is not
# recommended. 
# Ports should be set as the targetPort for all ClusterIP Services, and nodePorts for all NodePort Services 
# in the `ingress` namespace intended to be reachable from Traefik.
ingress_namespace_tcp_ports = []
ingress_namespace_udp_ports = []

# CHANGEME: set this to your home or VPN network range for accessing your cluster control plane remotely
external_control_plane_access_ranges = ["12.34.56.78/32"]

# Adjust the instance types and counts for the two node pools to provision different worker nodes.
# See here for lists of spec and pricing: https://cloud.google.com/compute/vm-instance-pricing
node_pools_first_instance_type   = "n2d-standard-2"
node_pools_first_instance_count  = 2
node_pools_second_instance_type  = "n2d-standard-4"
node_pools_second_instance_count = 1

# CHANGEME: set this to an email you want to use for registering with Let's Encrypt, so that Traefik will be able
# to request ACME TLS certificates on your behalf. Certificate expiration remainders will be sent here.
ingress_acme_account_email = "you@example.com"

# Set to a non-zero value (e.g. 7776000 for 90 days) for the period if you wish Cloud KMS to autorate managed keys.
# Since past data are not automatically reencrypted at rotation, past key versions will need to be kept active and
# incur an increasing (but small) charge over time. Therefore unless there is a strong security/compliance need
# you probably want to keep this at default 0.
kms_key_rotation_period_seconds = 0
