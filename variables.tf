variable "cloud" {
  description = "Cloud entry from clouds.yaml."
  type        = string
  default     = "tenant"
}

variable "cluster_name" {
  description = "Magnum cluster name."
  type        = string
  default     = "hermes-test"
}

variable "cluster_template_name" {
  description = "Existing validated Magnum Cluster API template name."
  type        = string
  default     = "k8s-capi-helm-ubuntu-v1.34.7"
}

variable "public_network_name" {
  description = "OpenStack external network name used for public floating IPs."
  type        = string
  default     = "public"
}

variable "magnum_image_name" {
  description = "Expected image behind the validated Magnum template."
  type        = string
  default     = "ubuntu-jammy-kube-v1.34.7"
}

variable "generated_dir" {
  description = "Directory for generated sensitive and rendered local artifacts."
  type        = string
  default     = "generated"
}

variable "keypair_name" {
  description = "Optional Nova keypair name override for generated SSH access."
  type        = string
  default     = null
  nullable    = true
}

variable "keypair_rsa_bits" {
  description = "RSA key size for the generated SSH keypair."
  type        = number
  default     = 4096
}

variable "worker_flavor" {
  description = "Flavor override for the default Magnum worker nodegroup."
  type        = string
  default     = "m1.medium"
}

variable "master_flavor" {
  description = "Flavor override for Magnum control plane nodes."
  type        = string
  default     = "m1.medium"
}

variable "gemma_nodegroup_name" {
  description = "Magnum nodegroup name for the dedicated large gemma4 worker."
  type        = string
  default     = "gemma4-large"
}

variable "gemma_worker_flavor" {
  description = "Flavor for the dedicated gemma4 nodegroup."
  type        = string
  default     = "m1.2xlarge"
}

variable "gemma_worker_count" {
  description = "Number of workers in the dedicated gemma4 nodegroup."
  type        = number
  default     = 1
}

variable "master_count" {
  description = "Number of Magnum control plane nodes."
  type        = number
  default     = 1
}

variable "node_count" {
  description = "Number of default Magnum worker nodes."
  type        = number
  default     = 1
}

variable "cluster_create_timeout" {
  description = "Cluster creation timeout in minutes."
  type        = number
  default     = 90
}

variable "node_ready_timeout_seconds" {
  description = "Timeout for waiting on the expected Kubernetes nodes to become Ready."
  type        = number
  default     = 1800
}

variable "kubernetes_namespace" {
  description = "Namespace for the Hermes/Gemma workloads."
  type        = string
  default     = "hermes"
}

variable "storage_class_name" {
  description = "StorageClass for the Ollama PVC."
  type        = string
  default     = "lvm"
}

variable "ollama_data_size" {
  description = "PVC size for Ollama model storage."
  type        = string
  default     = "40Gi"
}

variable "gemma_model" {
  description = "Default Ollama model to load."
  type        = string
  default     = "gemma4:26b"
}

variable "gemma_context_tokens" {
  description = "Context window presented to Hermes Agent for the local Gemma endpoint."
  type        = number
  default     = 262144
}

variable "hermes_image" {
  description = "Hermes Agent container image."
  type        = string
  default     = "nousresearch/hermes-agent:latest"
}

variable "hermes_data_size" {
  description = "PVC size for Hermes Agent state under /opt/data."
  type        = string
  default     = "10Gi"
}

variable "hermes_dashboard_port" {
  description = "Port exposed by the Hermes dashboard."
  type        = number
  default     = 9119
}

variable "hermes_dashboard_public_port" {
  description = "Public service port exposed by the Hermes dashboard LoadBalancer."
  type        = number
  default     = 80
}

variable "hermes_api_port" {
  description = "Port exposed by the Hermes OpenAI-compatible API server."
  type        = number
  default     = 8642
}

variable "hermes_dashboard_loadbalancer_enabled" {
  description = "Whether to expose the Hermes dashboard through a public OpenStack LoadBalancer service."
  type        = bool
  default     = true
}

variable "hermes_api_server_key" {
  description = "Optional API server bearer token override for Hermes. Leave null to derive a local-only value."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "hermes_api_server_model_name" {
  description = "Model name advertised by the Hermes OpenAI-compatible API server."
  type        = string
  default     = "hermes-agent"
}

variable "hermes_api_server_cors_origins" {
  description = "Comma-separated CORS origins for the Hermes API server when used from the dashboard over localhost port-forwarding."
  type        = string
  default     = "http://127.0.0.1:9119,http://localhost:9119"
}

variable "hermes_memory_request" {
  description = "Memory request for the Hermes Agent pod."
  type        = string
  default     = "512Mi"
}

variable "hermes_memory_limit" {
  description = "Memory limit for the Hermes Agent pod."
  type        = string
  default     = "2Gi"
}

variable "hermes_cpu_request" {
  description = "CPU request for the Hermes Agent pod."
  type        = string
  default     = "250m"
}

variable "hermes_cpu_limit" {
  description = "CPU limit for the Hermes Agent pod."
  type        = string
  default     = "1"
}
