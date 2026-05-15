locals {
  generated_dir                   = "${path.module}/${var.generated_dir}"
  generated_kubeconfig_dir        = "${local.generated_dir}/kubeconfig"
  kubeconfig_path                 = "${local.generated_kubeconfig_dir}/config"
  keypair_name                    = coalesce(var.keypair_name, "${var.cluster_name}-key")
  private_key_path                = "${local.generated_dir}/${local.keypair_name}.pem"
  workloads_path                  = "${local.generated_dir}/workloads.yaml"
  gemma_node_label_key            = "hermes.openstack.org/gemma4"
  gemma_node_label_value          = "true"
  expected_ready_nodes            = var.master_count + var.node_count + var.gemma_worker_count
  hermes_api_server_key           = coalesce(var.hermes_api_server_key, substr(sha256(tls_private_key.cluster_access.private_key_pem), 0, 32))
  hermes_dashboard_service        = "hermes"
  hermes_dashboard_public_service = "hermes-dashboard-public"
  hermes_dashboard_target_port    = 9119
  hermes_api_target_port          = 8642
  workloads_yaml = templatefile("${path.module}/templates/workloads.yaml.tftpl", {
    namespace                       = var.kubernetes_namespace
    storage_class_name              = var.storage_class_name
    ollama_data_size                = var.ollama_data_size
    gemma_node_label_key            = local.gemma_node_label_key
    gemma_node_label_value          = local.gemma_node_label_value
    gemma_model                     = var.gemma_model
    gemma_context_tokens            = var.gemma_context_tokens
    hermes_image                    = var.hermes_image
    hermes_data_size                = var.hermes_data_size
    hermes_dashboard_port           = var.hermes_dashboard_port
    hermes_dashboard_public_port    = var.hermes_dashboard_public_port
    hermes_dashboard_lb_enabled     = var.hermes_dashboard_loadbalancer_enabled
    hermes_dashboard_public_service = local.hermes_dashboard_public_service
    public_network_id               = data.openstack_networking_network_v2.public.id
    hermes_api_port                 = var.hermes_api_port
    hermes_api_server_key           = local.hermes_api_server_key
    hermes_api_server_model_name    = var.hermes_api_server_model_name
    hermes_api_server_cors          = var.hermes_api_server_cors_origins
    hermes_memory_request           = var.hermes_memory_request
    hermes_memory_limit             = var.hermes_memory_limit
    hermes_cpu_request              = var.hermes_cpu_request
    hermes_cpu_limit                = var.hermes_cpu_limit
  })
  workloads_yaml_hash = sha256(local.workloads_yaml)
}

data "openstack_containerinfra_clustertemplate_v1" "capi" {
  name = var.cluster_template_name
}

data "openstack_images_image_v2" "magnum" {
  name = var.magnum_image_name
}

data "openstack_networking_network_v2" "public" {
  name = var.public_network_name
}

resource "terraform_data" "generated_dirs" {
  provisioner "local-exec" {
    command     = "mkdir -p '${local.generated_kubeconfig_dir}'"
    interpreter = ["/bin/sh", "-c"]
  }
}

resource "tls_private_key" "cluster_access" {
  algorithm = "RSA"
  rsa_bits  = var.keypair_rsa_bits
}

resource "local_sensitive_file" "cluster_access_private_key" {
  depends_on      = [terraform_data.generated_dirs]
  filename        = local.private_key_path
  content         = tls_private_key.cluster_access.private_key_pem
  file_permission = "0600"
}

resource "openstack_compute_keypair_v2" "cluster_access" {
  name       = local.keypair_name
  public_key = tls_private_key.cluster_access.public_key_openssh
}

resource "openstack_containerinfra_cluster_v1" "hermes" {
  name                = var.cluster_name
  cluster_template_id = data.openstack_containerinfra_clustertemplate_v1.capi.id
  flavor              = var.worker_flavor
  master_flavor       = var.master_flavor
  master_count        = var.master_count
  node_count          = var.node_count
  create_timeout      = var.cluster_create_timeout
  keypair             = openstack_compute_keypair_v2.cluster_access.name
}

resource "terraform_data" "gemma_nodegroup" {
  depends_on = [openstack_containerinfra_cluster_v1.hermes]

  input = {
    cluster_name     = openstack_containerinfra_cluster_v1.hermes.name
    nodegroup_name   = var.gemma_nodegroup_name
    nodegroup_flavor = var.gemma_worker_flavor
    nodegroup_count  = tostring(var.gemma_worker_count)
    os_cloud         = var.cloud
    clouds_file_path = "${path.module}/clouds.yaml"
  }

  triggers_replace = [
    openstack_containerinfra_cluster_v1.hermes.id,
    var.gemma_nodegroup_name,
    var.gemma_worker_flavor,
    tostring(var.gemma_worker_count),
    data.openstack_images_image_v2.magnum.id,
  ]

  provisioner "local-exec" {
    working_dir = path.module
    interpreter = ["/bin/sh", "-c"]
    environment = {
      OS_CLIENT_CONFIG_FILE = "${path.module}/clouds.yaml"
      OS_CLOUD              = var.cloud
    }
    command = "./scripts/create-gemma-nodegroup.sh '${self.input.cluster_name}' '${self.input.nodegroup_name}' '${self.input.nodegroup_flavor}' '${self.input.nodegroup_count}'"
  }

  provisioner "local-exec" {
    when        = destroy
    working_dir = path.module
    interpreter = ["/bin/sh", "-c"]
    environment = {
      OS_CLIENT_CONFIG_FILE = self.input.clouds_file_path
      OS_CLOUD              = self.input.os_cloud
    }
    command = "./scripts/delete-gemma-nodegroup.sh '${self.input.cluster_name}' '${self.input.nodegroup_name}'"
  }
}

resource "terraform_data" "generated_kubeconfig" {
  depends_on = [openstack_containerinfra_cluster_v1.hermes, terraform_data.generated_dirs]

  triggers_replace = [
    openstack_containerinfra_cluster_v1.hermes.id,
    openstack_containerinfra_cluster_v1.hermes.api_address,
  ]

  provisioner "local-exec" {
    working_dir = path.module
    interpreter = ["/bin/sh", "-c"]
    environment = {
      OS_CLIENT_CONFIG_FILE = "${path.module}/clouds.yaml"
      OS_CLOUD              = var.cloud
    }
    command = <<-EOT
      set -eu
      mkdir -p '${local.generated_kubeconfig_dir}'
      rm -f '${local.kubeconfig_path}'
      openstack --os-cloud "$OS_CLOUD" coe cluster config '${var.cluster_name}' --dir '${local.generated_kubeconfig_dir}'
    EOT
  }
}

resource "local_sensitive_file" "workloads" {
  depends_on      = [terraform_data.generated_dirs]
  filename        = local.workloads_path
  content         = local.workloads_yaml
  file_permission = "0600"
}

resource "terraform_data" "wait_for_nodes" {
  depends_on = [
    terraform_data.generated_kubeconfig,
    terraform_data.gemma_nodegroup,
  ]

  triggers_replace = [
    openstack_containerinfra_cluster_v1.hermes.id,
    terraform_data.gemma_nodegroup.id,
    local.kubeconfig_path,
    tostring(local.expected_ready_nodes),
  ]

  provisioner "local-exec" {
    working_dir = path.module
    interpreter = ["/bin/sh", "-c"]
    environment = {
      KUBECONFIG = local.kubeconfig_path
    }
    command = <<-EOT
      set -eu
      deadline=$(( $(date +%s) + ${var.node_ready_timeout_seconds} ))
      while :; do
        total=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
        ready=$(kubectl get nodes --no-headers 2>/dev/null | awk '$2=="Ready"{c++} END{print c+0}')
        if [ "$total" -ge "${local.expected_ready_nodes}" ] && [ "$ready" -ge "${local.expected_ready_nodes}" ]; then
          break
        fi
        if [ "$(date +%s)" -ge "$deadline" ]; then
          kubectl get nodes -o wide || true
          exit 1
        fi
        sleep 15
      done
    EOT
  }
}

resource "terraform_data" "label_gemma_nodes" {
  depends_on = [terraform_data.wait_for_nodes]

  triggers_replace = [
    openstack_containerinfra_cluster_v1.hermes.id,
    terraform_data.gemma_nodegroup.id,
    var.gemma_nodegroup_name,
    local.kubeconfig_path,
  ]

  provisioner "local-exec" {
    working_dir = path.module
    interpreter = ["/bin/sh", "-c"]
    environment = {
      OS_CLIENT_CONFIG_FILE = "${path.module}/clouds.yaml"
      OS_CLOUD              = var.cloud
      KUBECONFIG            = local.kubeconfig_path
    }
    command = <<-EOT
      set -eu
      node_ips=$(
        openstack --os-cloud "$OS_CLOUD" coe nodegroup show '${var.cluster_name}' '${var.gemma_nodegroup_name}' -f yaml \
        | awk '
            /^node_addresses:/ {in_list=1; next}
            in_list && /^[[:space:]]*-[[:space:]]/ {print $2; next}
            in_list && !/^[[:space:]]*-[[:space:]]/ {in_list=0}
          '
      )
      if [ -n "$node_ips" ]; then
        for ip in $node_ips; do
          node_name=$(
            kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" "}{range .status.addresses[?(@.type=="InternalIP")]}{.address}{"\n"}{end}{end}' \
            | awk -v target="$ip" '$2==target {print $1}'
          )
          if [ -z "$node_name" ]; then
            echo "No Kubernetes node found for internal IP $ip" >&2
            kubectl get nodes -o wide >&2 || true
            exit 1
          fi
          kubectl label node "$node_name" '${local.gemma_node_label_key}=${local.gemma_node_label_value}' --overwrite
        done
        exit 0
      fi

      node_names=$(
        kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
        | awk '/-${var.gemma_nodegroup_name}-/ {print}'
      )
      if [ -z "$node_names" ]; then
        echo "Gemma nodegroup has no node addresses, and no Kubernetes nodes matched the nodegroup name." >&2
        openstack --os-cloud "$OS_CLOUD" coe nodegroup show '${var.cluster_name}' '${var.gemma_nodegroup_name}' -f yaml >&2
        kubectl get nodes -o wide >&2 || true
        exit 1
      fi
      for node_name in $node_names; do
        kubectl label node "$node_name" '${local.gemma_node_label_key}=${local.gemma_node_label_value}' --overwrite
      done
    EOT
  }
}

resource "terraform_data" "apply_workloads" {
  depends_on = [
    local_sensitive_file.workloads,
    terraform_data.label_gemma_nodes,
  ]

  triggers_replace = [
    openstack_containerinfra_cluster_v1.hermes.id,
    terraform_data.label_gemma_nodes.id,
    local.workloads_yaml_hash,
  ]

  provisioner "local-exec" {
    working_dir = path.module
    interpreter = ["/bin/sh", "-c"]
    environment = {
      KUBECONFIG = local.kubeconfig_path
    }
    command = "kubectl apply -f '${local.workloads_path}'"
  }
}
