variable "cloud" {
  description = "Cloud entry name resolved from the local clouds.yaml file."
  type        = string
  default     = "tenant"
}

variable "os_client_config_file" {
  description = "Optional explicit path to the local clouds.yaml file used by OpenStack CLI calls. Leave null to use ./clouds.yaml."
  type        = string
  default     = null
  nullable    = true
}

variable "cluster_name" {
  description = "Magnum cluster name."
  type        = string
  default     = "hermes-magnum"
}

variable "cluster_template_name" {
  description = "Existing Magnum cluster template name to instantiate."
  type        = string
  default     = "k8s-capi-helm-ubuntu-v1.34.7"
}

variable "magnum_image_name" {
  description = "Image name to use when creating additional Magnum nodegroups outside the base template."
  type        = string
  default     = "ubuntu-jammy-kube-v1.34.7"
}

variable "public_network_name" {
  description = "External OpenStack network name used for public floating IP allocation when the Hermes dashboard LoadBalancer is enabled."
  type        = string
  default     = "public"
}

variable "generated_dir" {
  description = "Directory for generated kubeconfig, rendered manifests, and generated private keys."
  type        = string
  default     = "generated"
}

variable "create_keypair" {
  description = "Whether Terraform should generate and register a new Nova keypair for Magnum nodes."
  type        = bool
  default     = true
}

variable "keypair_name" {
  description = "Optional Nova keypair name override when create_keypair is true."
  type        = string
  default     = null
  nullable    = true
}

variable "existing_keypair_name" {
  description = "Existing Nova keypair name to inject into Magnum nodes when create_keypair is false."
  type        = string
  default     = null
  nullable    = true
}

variable "keypair_rsa_bits" {
  description = "RSA key size for the generated SSH keypair."
  type        = number
  default     = 4096

  validation {
    condition     = var.keypair_rsa_bits >= 2048
    error_message = "keypair_rsa_bits must be at least 2048."
  }
}

variable "master_flavor" {
  description = "Flavor override for Magnum control plane nodes."
  type        = string
  default     = "m1.medium"
}

variable "worker_flavor" {
  description = "Flavor override for the default Magnum worker nodegroup created with the base cluster."
  type        = string
  default     = "m1.medium"
}

variable "master_count" {
  description = "Number of Magnum control plane nodes."
  type        = number
  default     = 1

  validation {
    condition     = var.master_count >= 1
    error_message = "master_count must be at least 1."
  }
}

variable "node_count" {
  description = "Number of Magnum workers in the default nodegroup created with the base cluster."
  type        = number
  default     = 1

  validation {
    condition     = var.node_count >= 0
    error_message = "node_count cannot be negative."
  }
}

variable "cluster_create_timeout" {
  description = "Cluster creation timeout in minutes."
  type        = number
  default     = 90

  validation {
    condition     = var.cluster_create_timeout > 0
    error_message = "cluster_create_timeout must be greater than zero."
  }
}

variable "node_ready_timeout_seconds" {
  description = "Timeout for waiting until the expected Kubernetes nodes are Ready."
  type        = number
  default     = 1800

  validation {
    condition     = var.node_ready_timeout_seconds > 0
    error_message = "node_ready_timeout_seconds must be greater than zero."
  }
}

variable "deploy_workloads" {
  description = "Whether Terraform should render and apply the Gemma and Hermes Kubernetes workloads."
  type        = bool
  default     = true
}

variable "workload_rollout_timeout_seconds" {
  description = "Timeout for Kubernetes workload rollouts after manifests are applied."
  type        = number
  default     = 1800

  validation {
    condition     = var.workload_rollout_timeout_seconds > 0
    error_message = "workload_rollout_timeout_seconds must be greater than zero."
  }
}

variable "loadbalancer_ready_timeout_seconds" {
  description = "Timeout for waiting on a public Hermes dashboard load balancer address."
  type        = number
  default     = 1200

  validation {
    condition     = var.loadbalancer_ready_timeout_seconds > 0
    error_message = "loadbalancer_ready_timeout_seconds must be greater than zero."
  }
}

variable "gemma_nodegroup_enabled" {
  description = "Whether to create a dedicated Magnum nodegroup for Gemma."
  type        = bool
  default     = true
}

variable "gemma_nodegroup_name" {
  description = "Magnum nodegroup name for the dedicated Gemma worker pool."
  type        = string
  default     = "gemma-large"
}

variable "gemma_worker_flavor" {
  description = "Flavor for the dedicated Gemma nodegroup."
  type        = string
  default     = "m1.2xlarge"
}

variable "gemma_worker_count" {
  description = "Worker count for the dedicated Gemma nodegroup."
  type        = number
  default     = 1

  validation {
    condition     = var.gemma_worker_count >= 0
    error_message = "gemma_worker_count cannot be negative."
  }
}

variable "gemma_node_label_key" {
  description = "Kubernetes node label key applied to Gemma nodegroup nodes."
  type        = string
  default     = "hermes.openstack.org/gemma4"
}

variable "gemma_node_label_value" {
  description = "Kubernetes node label value applied to Gemma nodegroup nodes."
  type        = string
  default     = "true"
}

variable "kubernetes_namespace" {
  description = "Namespace for the Hermes and Gemma workloads."
  type        = string
  default     = "hermes"
}

variable "storage_class_name" {
  description = "Optional Kubernetes StorageClass name for both PVCs. Leave empty to use the cluster default StorageClass."
  type        = string
  default     = ""
}

variable "ollama_image" {
  description = "Container image for the Ollama runtime hosting Gemma."
  type        = string
  default     = "ollama/ollama:latest"
}

variable "model_loader_image" {
  description = "Utility image used by the Gemma model-loader sidecar."
  type        = string
  default     = "curlimages/curl:8.13.0"
}

variable "ollama_data_size" {
  description = "PVC size for Ollama model storage."
  type        = string
  default     = "40Gi"
}

variable "ollama_keep_alive" {
  description = "OLLAMA_KEEP_ALIVE value passed to the Ollama container."
  type        = string
  default     = "24h"
}

variable "gemma_model" {
  description = "Ollama model name to pull and expose to Hermes."
  type        = string
  default     = "gemma4:26b"
}

variable "gemma_context_tokens" {
  description = "Context length advertised to Hermes for the Gemma endpoint."
  type        = number
  default     = 262144

  validation {
    condition     = var.gemma_context_tokens > 0
    error_message = "gemma_context_tokens must be greater than zero."
  }
}

variable "gemma_memory_request" {
  description = "Memory request for the Ollama container."
  type        = string
  default     = "20Gi"
}

variable "gemma_memory_limit" {
  description = "Memory limit for the Ollama container."
  type        = string
  default     = "22Gi"
}

variable "gemma_cpu_request" {
  description = "Optional CPU request for the Ollama container. Leave empty to omit it."
  type        = string
  default     = ""
}

variable "gemma_cpu_limit" {
  description = "Optional CPU limit for the Ollama container. Leave empty to omit it."
  type        = string
  default     = ""
}

variable "gemma_service_name" {
  description = "Kubernetes Service name for the in-cluster Gemma endpoint."
  type        = string
  default     = "gemma4"
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

variable "hermes_service_name" {
  description = "Internal Kubernetes Service name for the Hermes API and dashboard."
  type        = string
  default     = "hermes"
}

variable "hermes_dashboard_public_service_name" {
  description = "Public Kubernetes Service name for the Hermes dashboard LoadBalancer."
  type        = string
  default     = "hermes-dashboard-public"
}

variable "hermes_dashboard_port" {
  description = "Port exposed by the Hermes dashboard inside the cluster."
  type        = number
  default     = 9119

  validation {
    condition     = var.hermes_dashboard_port > 0 && var.hermes_dashboard_port < 65536
    error_message = "hermes_dashboard_port must be a valid TCP port."
  }
}

variable "hermes_dashboard_public_port" {
  description = "Public port exposed by the Hermes dashboard LoadBalancer."
  type        = number
  default     = 80

  validation {
    condition     = var.hermes_dashboard_public_port > 0 && var.hermes_dashboard_public_port < 65536
    error_message = "hermes_dashboard_public_port must be a valid TCP port."
  }
}

variable "hermes_api_port" {
  description = "Port exposed by the Hermes OpenAI-compatible API server."
  type        = number
  default     = 8642

  validation {
    condition     = var.hermes_api_port > 0 && var.hermes_api_port < 65536
    error_message = "hermes_api_port must be a valid TCP port."
  }
}

variable "hermes_dashboard_loadbalancer_enabled" {
  description = "Whether to expose the Hermes dashboard with a public Kubernetes LoadBalancer service."
  type        = bool
  default     = true
}

variable "hermes_api_server_key" {
  description = "Optional bearer token override for the Hermes API server. Leave null to generate a local-only value."
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
  description = "Comma-separated CORS origins for the Hermes API server."
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
