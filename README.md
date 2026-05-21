# Hermes + Gemma on OpenStack Magnum

Terraform project for deploying a configurable `hermes-agent` + Gemma stack on top of an existing OpenStack Magnum Kubernetes template.

The design target is tenant-scoped automation:

- OpenStack authentication stays local to the project.
- Terraform uses the official OpenStack provider for the Magnum cluster lifecycle.
- A tenant-side OpenStack CLI hook adds an optional dedicated Magnum nodegroup for Gemma when you need a larger worker flavor than the default worker pool.
- Terraform renders kubeconfig and Kubernetes manifests under `generated/`, then can apply the workloads automatically.

## What This Repository Does

- Creates or reuses an SSH keypair and injects it into all Magnum nodes.
- Instantiates an existing Magnum cluster template.
- Optionally creates a dedicated Gemma nodegroup with a different flavor.
- Fetches kubeconfig locally.
- Deploys Ollama hosting a configurable Gemma model.
- Deploys `nousresearch/hermes-agent` configured to use the in-cluster Gemma endpoint.
- Optionally exposes the Hermes dashboard through an OpenStack-backed Kubernetes `LoadBalancer`.

## Architecture

The deployment flow is:

1. Keystone authenticates the tenant application credential from the local `clouds.yaml`.
2. Terraform creates a Magnum cluster from an existing cluster template.
3. Terraform uses the OpenStack CLI to create an extra Magnum nodegroup when `gemma_nodegroup_enabled = true`.
4. Terraform fetches kubeconfig with `openstack coe cluster config`.
5. Terraform labels the dedicated Gemma worker nodes.
6. Terraform renders Kubernetes manifests into `generated/workloads.yaml`.
7. Terraform applies Gemma and Hermes into the target namespace.
8. If enabled, the Hermes dashboard is published through Kubernetes `Service type: LoadBalancer`, which OpenStack Cloud Controller Manager maps to Octavia.

## Repository Layout

```text
.
├── .gitignore
├── README.md
├── k8s/
│   ├── gemma4.yaml
│   └── hermes.yaml
├── main.tf
├── outputs.tf
├── scripts/
│   ├── create-gemma-nodegroup.sh
│   ├── delete-gemma-nodegroup.sh
│   └── get-kubeconfig.sh
├── templates/
│   └── workloads.yaml.tftpl
├── terraform.tfvars.example
├── variables.tf
└── versions.tf
```

## Security Model

- `clouds.yaml` is local-only and gitignored.
- `terraform.tfvars` is gitignored.
- `generated/` is gitignored because it contains kubeconfig, rendered manifests, and generated keys.
- `terraform.tfstate*` is gitignored and should be treated as sensitive.
- This repository does not rely on `~/.config/openstack`.
- This repository is designed for normal tenant application-credential operation, not admin credentials.

## Cloud Requirements

This repository is generic, but the cloud still needs several Magnum capabilities already in place:

- A working Magnum service.
- An existing Magnum cluster template that your tenant can use.
- A Glance image compatible with that template and with any extra nodegroups you plan to create.
- A working Cinder CSI / StorageClass path if you want persistent Ollama and Hermes volumes.
- A working OpenStack Cloud Controller Manager + Octavia path if you enable the public Hermes dashboard LoadBalancer.
- A shared Designate zone if `hermes_dashboard_dns_enabled = true`; for example, an admin-owned `apps.mustelinet.com.` zone must be shared to the tenant project before the tenant application credential can manage records.
- A Magnum driver path that supports nodegroups if you enable `gemma_nodegroup_enabled`.

For application-credential auth, Magnum commonly also needs an unrestricted application credential because cluster creation uses Keystone trusts.

If dashboard DNS management is enabled and the DNS zone is admin-owned, share the zone with the tenant project before applying:

```sh
openstack zone share create apps.mustelinet.com. 93dfe616bc234d37abc0e831f2b4e18f
```

## Local Authentication Setup

Create a project-local `clouds.yaml` in the repository root:

```yaml
clouds:
  tenant:
    auth_type: v3applicationcredential
    auth:
      auth_url: https://auth.mustelinet.com
      application_credential_id: CHANGE_ME
      application_credential_secret: CHANGE_ME
    region_name: RegionOne
    interface: public
    identity_api_version: 3
```

Protect the file and export the local auth context:

```sh
chmod 600 clouds.yaml
export OS_CLIENT_CONFIG_FILE="$PWD/clouds.yaml"
export OS_CLOUD=tenant
```

If you need to create a new application credential from a user-scoped session, one common pattern is:

```sh
openstack application credential create --unrestricted hermes-magnum
```

## Host Prerequisites

Required commands:

- `terraform`
- `openstack`
- `kubectl`
- Magnum CLI support for `openstack coe ...`
- Designate CLI support for `openstack recordset ...` when `hermes_dashboard_dns_enabled = true`
- `cloudflared` when connecting to VMs over SSH through the Mustelinet Cloudflare Access bastion

One Fedora installation pattern is:

```sh
curl -fsSL https://pkg.cloudflare.com/cloudflared.repo | sudo tee /etc/yum.repos.d/cloudflared.repo
sudo dnf install -y python3-openstackclient python3-magnumclient python3-designateclient kubernetes1.33-client cloudflared
```

On Ubuntu or Debian, install `cloudflared` with:

```sh
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt update
sudo apt install -y cloudflared
```

Install the OpenStack and Kubernetes CLIs through your distribution packages or Python environment on Ubuntu/Debian:

```sh
sudo apt install -y python3-openstackclient kubernetes-client
```

Verify your auth and tooling before Terraform:

```sh
terraform version
openstack --os-cloud "$OS_CLOUD" token issue
kubectl version --client
```

## Required OpenStack Inputs

This repository does not create the Magnum cluster template. You must provide these cloud-specific inputs:

- `cluster_template_name`
- `magnum_image_name`
- `public_network_name` when `hermes_dashboard_loadbalancer_enabled = true`
- `master_flavor`
- `worker_flavor`
- `gemma_worker_flavor` when `gemma_nodegroup_enabled = true`

The template should already encode the Magnum driver-specific labels your cloud requires. This repository intentionally consumes that template rather than attempting to rebuild it generically from Terraform.

## Quick Start

1. Enter the project:

   ```sh
   cd hermes_openstack
   ```

2. Create local auth and export the project-local environment:

   ```sh
   chmod 600 clouds.yaml
   export OS_CLIENT_CONFIG_FILE="$PWD/clouds.yaml"
   export OS_CLOUD=tenant
   ```

3. Copy the example variable file and edit it:

   ```sh
   cp terraform.tfvars.example terraform.tfvars
   ```

4. Confirm the required OpenStack objects exist.
   Query the exact template, image, flavors, and external network you put into `terraform.tfvars`.

5. Initialize and validate:

   ```sh
   terraform init -upgrade
   terraform fmt -recursive
   terraform validate
   terraform plan
   ```

6. Apply:

   ```sh
   terraform apply
   ```

7. Export kubeconfig and inspect the cluster:

   ```sh
   export KUBECONFIG="$PWD/generated/kubeconfig/config"
   kubectl get nodes -o wide
   kubectl -n hermes get pods -o wide
   kubectl -n hermes get svc
   ```

8. Access Hermes:

   If `hermes_dashboard_loadbalancer_enabled = true`, wait for:

   ```sh
   kubectl -n hermes get svc "$(terraform output -raw hermes_dashboard_public_service_name)" -w
   ```

   Or access it locally:

   ```sh
   kubectl -n hermes port-forward svc/"$(terraform output -raw hermes_service_name)" 9119:9119 8642:8642
   ```

## SSH Access Through Cloudflare Bastion

SSH access to hosts under `*.apps.mustelinet.com` goes through the Cloudflare Access bastion at `ssh.mustelinet.com`. After installing `cloudflared`, add this to `~/.ssh/config`:

```sshconfig
Host *.apps.mustelinet.com
    User ubuntu
    ProxyCommand cloudflared access ssh --hostname ssh.mustelinet.com --destination %h:%p
    ServerAliveInterval 30
```

Use the default user for your VM image. For Ubuntu images, keep `User ubuntu`; for a different image family, replace it with that image's default SSH user.

Test with:

```sh
ssh ubuntu@vm-test.apps.mustelinet.com
```

You can also rely on the configured user:

```sh
ssh vm-test.apps.mustelinet.com
```

## Common Customization

The fastest way to adapt the deployment is `terraform.tfvars`.

Common infrastructure knobs:

- `cluster_template_name`
- `magnum_image_name`
- `master_flavor`
- `worker_flavor`
- `master_count`
- `node_count`
- `create_keypair`
- `existing_keypair_name`

Common Gemma knobs:

- `gemma_nodegroup_enabled`
- `gemma_worker_flavor`
- `gemma_worker_count`
- `ollama_image`
- `gemma_model`
- `gemma_memory_request`
- `gemma_memory_limit`
- `gemma_cpu_request`
- `gemma_cpu_limit`
- `ollama_keep_alive`

Common Hermes knobs:

- `hermes_image`
- `hermes_data_size`
- `hermes_dashboard_loadbalancer_enabled`
- `hermes_dashboard_public_port`
- `hermes_dashboard_dns_enabled`
- `hermes_dashboard_dns_zone_name`
- `hermes_dashboard_dns_name`
- `hermes_dashboard_dns_ttl`
- `hermes_api_port`
- `hermes_api_server_model_name`
- `hermes_api_server_cors_origins`

Common storage and namespace knobs:

- `kubernetes_namespace`
- `storage_class_name`
- `ollama_data_size`
- `hermes_data_size`

## How the Magnum Integration Works

Magnum is the OpenStack service that turns Kubernetes clusters into first-class OpenStack resources.

This repository uses Magnum in two layers:

1. Terraform creates the base cluster by calling the official OpenStack provider resource `openstack_containerinfra_cluster_v1`.
2. Local CLI hooks call `openstack coe nodegroup ...` because the official Terraform provider does not currently expose Magnum nodegroups as first-class resources.

That hybrid model is deliberate:

- the base cluster stays declarative in Terraform
- the extra Gemma nodegroup still stays tenant-scoped
- the repository keeps using the official provider instead of a niche fork

### Magnum Object Model

The Magnum objects that matter here are:

- `Cluster template`
  This is the cloud-side recipe. It defines the driver path, image family, storage driver, network behavior, and the labels Magnum needs for that driver.
- `Cluster`
  This is the Kubernetes cluster instance created from the template. Terraform manages this part directly with `openstack_containerinfra_cluster_v1`.
- `Nodegroup`
  This is a worker pool inside a cluster. Nodegroups are how you mix worker flavors, which is why Gemma can run on a larger worker than the default Hermes worker pool.
- `Cluster config`
  This is the kubeconfig material returned by `openstack coe cluster config`, which Terraform writes under `generated/kubeconfig`.

### CLI to API Mental Model

Most operators never need to call Magnum's REST API directly, but it helps to understand how the CLI maps onto it:

- `openstack coe cluster template show <template>`
  Reads the cluster template object Magnum exposes through its API.
- `openstack coe cluster create ...`
  Creates the cluster resource that Magnum will realize.
- `openstack coe cluster show <cluster> -f yaml`
  Shows the authoritative cluster status and status reason.
- `openstack coe nodegroup create ...`
  Adds a worker pool with its own flavor and size.
- `openstack coe cluster config <cluster>`
  Retrieves the kubeconfig for the realized Kubernetes control plane.

### Why the Repository Uses Terraform Plus CLI

The official Terraform provider covers Magnum clusters, but not Magnum nodegroups. That leaves two choices:

- switch to a niche provider fork
- keep the official provider and handle nodegroups through the OpenStack CLI

This repository deliberately chooses the second path. It keeps the most important lifecycle object, the cluster itself, declarative in Terraform while still allowing one larger Gemma worker pool through tenant-scoped CLI hooks.

### Operational Consequence

When Terraform and Magnum disagree, Magnum is the source of truth. In practice, that means:

- use `openstack --os-cloud "$OS_CLOUD" coe cluster show <cluster> -f yaml` to inspect real cluster status
- use `openstack --os-cloud "$OS_CLOUD" coe nodegroup list <cluster>` to inspect additional worker pools
- use `terraform apply -refresh-only` when Magnum succeeds but the provider waiter lags behind

## Operations

Fetch kubeconfig again:

```sh
./scripts/get-kubeconfig.sh
```

Destroy everything Terraform manages:

```sh
terraform destroy
```

If you enabled the dedicated Gemma nodegroup, `terraform destroy` also calls the delete helper for that nodegroup.

## Troubleshooting

`terraform apply` fails early with a trust or trustee error:

- Check that the tenant application credential is unrestricted.
- If that is already true, the remaining issue is usually Magnum service-side trust configuration.

`terraform apply` reports a Magnum waiter failure but the cluster may still be progressing:

- Inspect Magnum directly:

  ```sh
  openstack --os-cloud "$OS_CLOUD" coe cluster show "$(terraform output -raw cluster_name)" -f yaml
  ```

- If Magnum reaches `CREATE_COMPLETE`, reconcile Terraform state:

  ```sh
  terraform apply -refresh-only
  ```

Gemma never schedules:

- Increase `gemma_worker_flavor`.
- Check `gemma_memory_request` and `gemma_memory_limit`.
- Confirm the dedicated nodegroup exists and the node got the expected label.

Hermes dashboard never gets a public IP:

- Confirm `hermes_dashboard_loadbalancer_enabled = true`.
- Confirm OpenStack Cloud Controller Manager is installed in the cluster.
- Confirm Octavia and the external network path are working.

PVCs stay Pending:

- Set `storage_class_name` explicitly if your cluster has no default StorageClass.
- Confirm the Magnum template and cloud CSI path support persistent volumes.

## Reference Files

- `variables.tf` is the full input contract.
- `terraform.tfvars.example` is the quickest starting point.
- `templates/workloads.yaml.tftpl` is the authoritative Kubernetes render source.
- `k8s/` contains reference fragments matching the default generated deployment.
- The Magnum API section in this README explains the object model and the Terraform CLI split.
