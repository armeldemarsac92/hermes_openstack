output "cluster_name" {
  description = "Created Magnum cluster name."
  value       = openstack_containerinfra_cluster_v1.hermes.name
}

output "cluster_id" {
  description = "Created Magnum cluster UUID."
  value       = openstack_containerinfra_cluster_v1.hermes.id
}

output "cluster_api_address" {
  description = "Kubernetes API endpoint reported by Magnum."
  value       = openstack_containerinfra_cluster_v1.hermes.api_address
}

output "cluster_template_name" {
  description = "Resolved Magnum cluster template name."
  value       = data.openstack_containerinfra_clustertemplate_v1.capi.name
}

output "cluster_template_id" {
  description = "Resolved Magnum cluster template UUID."
  value       = data.openstack_containerinfra_clustertemplate_v1.capi.id
}

output "cluster_template_labels" {
  description = "Resolved Magnum cluster template labels."
  value       = data.openstack_containerinfra_clustertemplate_v1.capi.labels
}

output "magnum_image_name" {
  description = "Resolved image name used for additional Magnum nodegroups."
  value       = data.openstack_images_image_v2.magnum.name
}

output "magnum_image_id" {
  description = "Resolved image UUID used for additional Magnum nodegroups."
  value       = data.openstack_images_image_v2.magnum.id
}

output "public_network_id" {
  description = "Resolved OpenStack external network UUID used for the Hermes dashboard LoadBalancer."
  value       = var.hermes_dashboard_loadbalancer_enabled ? data.openstack_networking_network_v2.public[0].id : null
}

output "keypair_name" {
  description = "Nova keypair injected into Magnum nodes."
  value       = local.keypair_name
}

output "private_key_path" {
  description = "Local filesystem path for the generated SSH private key, or null when using an existing keypair."
  value       = local.private_key_path
}

output "kubeconfig_path" {
  description = "Local filesystem path for the generated kubeconfig."
  value       = local.kubeconfig_path
}

output "workloads_path" {
  description = "Local filesystem path for the rendered Kubernetes manifest, or null when deploy_workloads is false."
  value       = var.deploy_workloads ? "${local.generated_dir}/workloads.yaml" : null
}

output "gemma_nodegroup_enabled" {
  description = "Whether Terraform manages a dedicated Gemma Magnum nodegroup."
  value       = var.gemma_nodegroup_enabled
}

output "gemma_nodegroup_name" {
  description = "Magnum nodegroup name for the dedicated Gemma worker pool."
  value       = var.gemma_nodegroup_enabled ? var.gemma_nodegroup_name : null
}

output "gemma_worker_flavor" {
  description = "Flavor for the dedicated Gemma nodegroup."
  value       = var.gemma_nodegroup_enabled ? var.gemma_worker_flavor : null
}

output "gemma_worker_count" {
  description = "Worker count for the dedicated Gemma nodegroup."
  value       = var.gemma_nodegroup_enabled ? var.gemma_worker_count : null
}

output "gemma_node_label" {
  description = "Node label used to pin the Gemma workload to the dedicated nodegroup."
  value = var.gemma_nodegroup_enabled ? {
    key   = var.gemma_node_label_key
    value = var.gemma_node_label_value
  } : null
}

output "gemma_service_name" {
  description = "Kubernetes Service name for the in-cluster Gemma endpoint."
  value       = var.gemma_service_name
}

output "hermes_service_name" {
  description = "Internal Kubernetes Service name exposing the Hermes dashboard and API."
  value       = var.hermes_service_name
}

output "hermes_dashboard_public_service_name" {
  description = "Public Kubernetes Service name exposing the Hermes dashboard through OpenStack load balancing."
  value       = var.hermes_dashboard_loadbalancer_enabled ? var.hermes_dashboard_public_service_name : null
}

output "hermes_dashboard_port" {
  description = "Internal service port for the Hermes dashboard."
  value       = var.hermes_dashboard_port
}

output "hermes_dashboard_public_port" {
  description = "Public service port for the Hermes dashboard."
  value       = var.hermes_dashboard_loadbalancer_enabled ? var.hermes_dashboard_public_port : null
}

output "hermes_api_port" {
  description = "Service port for the Hermes OpenAI-compatible API server."
  value       = var.hermes_api_port
}
