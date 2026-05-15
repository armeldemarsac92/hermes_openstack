output "cluster_name" {
  description = "Created Magnum cluster name."
  value       = openstack_containerinfra_cluster_v1.hermes.name
}

output "cluster_template_name" {
  description = "Resolved Magnum cluster template name."
  value       = data.openstack_containerinfra_clustertemplate_v1.capi.name
}

output "cluster_template_id" {
  description = "Resolved Magnum cluster template ID."
  value       = data.openstack_containerinfra_clustertemplate_v1.capi.id
}

output "cluster_template_labels" {
  description = "Resolved Magnum cluster template labels."
  value       = data.openstack_containerinfra_clustertemplate_v1.capi.labels
}

output "cluster_api_address" {
  description = "Kubernetes API endpoint reported by Magnum."
  value       = openstack_containerinfra_cluster_v1.hermes.api_address
}

output "cluster_master_addresses" {
  description = "Master node addresses reported by Magnum."
  value       = openstack_containerinfra_cluster_v1.hermes.master_addresses
}

output "cluster_node_addresses" {
  description = "Worker node addresses reported by Magnum."
  value       = openstack_containerinfra_cluster_v1.hermes.node_addresses
}

output "magnum_image_id" {
  description = "Resolved backing image ID for the validated template."
  value       = data.openstack_images_image_v2.magnum.id
}

output "public_network_id" {
  description = "Resolved OpenStack public network ID used for dashboard floating IP allocation."
  value       = data.openstack_networking_network_v2.public.id
}

output "keypair_name" {
  description = "Generated Nova keypair name injected into Magnum nodes."
  value       = openstack_compute_keypair_v2.cluster_access.name
}

output "private_key_path" {
  description = "Local filesystem path for the generated SSH private key."
  value       = local.private_key_path
}

output "kubeconfig_path" {
  description = "Local filesystem path for the generated kubeconfig."
  value       = local.kubeconfig_path
}

output "workloads_path" {
  description = "Local filesystem path for the rendered Kubernetes workloads manifest."
  value       = local.workloads_path
}

output "gemma_nodegroup_name" {
  description = "Name of the dedicated large gemma4 Magnum nodegroup."
  value       = var.gemma_nodegroup_name
}

output "gemma_worker_flavor" {
  description = "Flavor for the dedicated large gemma4 Magnum nodegroup."
  value       = var.gemma_worker_flavor
}

output "gemma_worker_count" {
  description = "Node count for the dedicated large gemma4 Magnum nodegroup."
  value       = var.gemma_worker_count
}

output "hermes_service_name" {
  description = "Kubernetes Service name exposing the Hermes dashboard and API server."
  value       = local.hermes_dashboard_service
}

output "hermes_dashboard_public_service_name" {
  description = "Kubernetes LoadBalancer Service name exposing the Hermes dashboard publicly."
  value       = local.hermes_dashboard_public_service
}

output "hermes_dashboard_port" {
  description = "Internal service port for the Hermes dashboard."
  value       = var.hermes_dashboard_port
}

output "hermes_dashboard_public_port" {
  description = "Public LoadBalancer service port for the Hermes dashboard."
  value       = var.hermes_dashboard_public_port
}

output "hermes_api_port" {
  description = "Service port for the Hermes OpenAI-compatible API server."
  value       = var.hermes_api_port
}
