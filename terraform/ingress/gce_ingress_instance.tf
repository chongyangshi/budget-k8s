// For ingress we use a GCE instance on non-preemptible mode with a public IP.
// We don't use a load balancer due to its standing cost in contrast with the
// lack of high-availability guarantees of personal projects. 
// We also can't launch this instance with an instance group as we will not be
