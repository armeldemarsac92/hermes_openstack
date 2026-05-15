# test-hermes

Local Terraform test project for validating tenant-scoped Terraform interoperability against the OpenStack cloud at `http://10.20.0.50:5000` with application credentials only.

## Goals

- Keep all OpenStack auth local to this project.
- Provision one Magnum Kubernetes cluster in the application credential's project.
- Use the cloud's validated Magnum Cluster API template path instead of the deprecated Heat/FCOS flow.
- Deploy `gemma4` on a dedicated large worker, exposed only by a Kubernetes ClusterIP service on port `11434`.
- Deploy the real `NousResearch/hermes-agent` container, configured to use the in-cluster Gemma/Ollama endpoint.
- Keep the Hermes API server internal, but expose the Hermes dashboard through an OpenStack-backed Kubernetes `LoadBalancer` service with a floating IP on the `public` network.

## Files

```text
.
├── .gitignore
├── README.md
├── generated
├── templates
│   └── workloads.yaml.tftpl
├── k8s
│   ├── gemma4.yaml
│   └── hermes.yaml
├── main.tf
├── outputs.tf
├── scripts
│   ├── create-gemma-nodegroup.sh
│   ├── delete-gemma-nodegroup.sh
│   └── get-kubeconfig.sh
├── terraform.tfvars.example
├── variables.tf
└── versions.tf
```

## Security

- `clouds.yaml` must stay local and is gitignored.
- `clouds.yaml.example` is intentionally not committed. Keep any auth examples local-only.
- `terraform.tfvars` is gitignored in case you choose to store overrides there.
- `generated/` is gitignored because it contains kubeconfig material, rendered manifests, and local secrets.
- Do not use `admin-openrc` for this test.
- If Magnum or another API rejects a resource because tenant credentials are insufficient, stop there and investigate policy instead of switching to admin.

## Host preflight

Confirm the host reaches Keystone through WARP/Cloudflare before touching Terraform:

```sh
ip route get 10.20.0.50
curl -I http://10.20.0.50:5000
```

Expected shape:

- the route should go out via your WARP interface
- Keystone should answer on `http://10.20.0.50:5000` and typically redirect to `/v3/`

## Host tooling

Required commands:

- `terraform`
- `openstack`
- `kubectl`
- Magnum client support for `openstack coe ...`

On Fedora 42, one working install pattern is:

```sh
sudo dnf install -y python3-openstackclient python3-magnumclient kubernetes1.33-client
```

This cloud's validated Magnum template currently creates Kubernetes `v1.34.7`. If your installed `kubectl` is far from that server minor version, prefer a closer client build before cluster testing.

## Local auth setup

Create a local `clouds.yaml` file and replace the placeholders with a tenant-scoped application credential:

```sh
chmod 600 clouds.yaml
```

Expected local-only `clouds.yaml` shape:

```yaml
clouds:
  tenant:
    auth_type: v3applicationcredential
    auth:
      auth_url: http://10.20.0.50:5000
      application_credential_id: CHANGE_ME
      application_credential_secret: CHANGE_ME
    region_name: RegionOne
    interface: public
    identity_api_version: 3
```

Export project-local auth variables:

```sh
export OS_CLIENT_CONFIG_FILE="$PWD/clouds.yaml"
export OS_CLOUD=tenant
```

## Magnum trust requirement

Magnum cluster creation is stricter than basic Nova/Neutron/Glance checks because Magnum creates a Keystone trust during cluster provisioning.

Important implications:

- A default restricted application credential is usually not enough for Magnum cluster creation.
- If you want to use an application credential with Magnum, create it as `--unrestricted`.
- If an unrestricted application credential still fails with `Failed to create trustee or trust`, the next place to inspect is the Magnum service configuration on the cloud side.
- Keep using tenant/app-credential auth only for this project. Do not switch to admin-openrc on the host.

Example creation pattern from a user session with the right project scope:

```sh
openstack application credential create --unrestricted hermes-magnum
```

## Validated cloud template

As of May 15, 2026, the cloud-side validated Magnum Cluster API template is:

- template name: `k8s-capi-helm-ubuntu-v1.34.7`
- template UUID: `0f743d8c-b7d8-48e8-9a4e-7bfb815771c1`
- image name: `ubuntu-jammy-kube-v1.34.7`
- image UUID: `f793b1c2-1d1d-42e0-be6a-c77f327ef48e`
- Kubernetes version: `v1.34.7`
- distro: `ubuntu`
- volume driver: `cinder`
- network driver: `flannel`
- important template labels:
  - `capi_helm_chart_version=0.25.0`
  - `octavia_provider=ovn`
  - `auto_healing_enabled=true`
  - Kubernetes version comes from the image property

This Terraform project does not recreate that template tenant-side. It consumes the validated public template directly so the test stays aligned with the working Magnum CAPI driver path.

The official OpenStack Terraform provider does not model Magnum nodegroups directly. To keep using the official provider and still give `gemma4` a large worker, this project uses a hybrid design:

- Terraform creates the base cluster with:
  - control plane flavor `m1.medium`
  - default worker flavor `m1.medium`
  - default worker count `1`
- a tenant-side helper script creates one extra Magnum nodegroup:
  - nodegroup name `gemma4-large`
  - worker flavor `m1.2xlarge`
  - worker count `1`

That gives the cluster two workers total while keeping only the `gemma4` worker large enough for the `20Gi` memory request.

## Terraform design

- Provider: `terraform-provider-openstack/openstack ~> 3.4`
- Auth source: `provider "openstack" { cloud = var.cloud }`
- Magnum template source: existing public Cluster API template resolved by name
- Expected backing image lookup: `ubuntu-jammy-kube-v1.34.7`
- Terraform generates one local RSA keypair, registers it as a Nova keypair, and injects it into all Magnum nodes.
- Terraform creates the base cluster with:
  - default workers `m1.medium`
  - control plane `m1.medium`
  - `master_count = 1`
  - `node_count = 1`
- Terraform then creates one dedicated Magnum nodegroup:
  - name `gemma4-large`
  - `node_count = 1`
  - flavor `m1.2xlarge`
- Terraform writes local artifacts under `generated/`:
  - `generated/kubeconfig/config`
  - `generated/hermes-test-key.pem`
  - `generated/workloads.yaml`
- The rendered Kubernetes manifest bootstraps:
  - `gemma4` with Ollama model storage on Cinder
  - `hermes` as a real `nousresearch/hermes-agent` deployment
  - an internal Hermes service on ports `9119` and `8642`
  - a public `LoadBalancer` service for the Hermes dashboard
  - Hermes API server remains internal on port `8642`
- Hermes is configured with `provider: custom` and `base_url: http://gemma4:11434/v1`, per the Hermes Agent custom-endpoint documentation for local Ollama-style servers.
- Terraform resolves the OpenStack `public` network ID and annotates the dashboard `LoadBalancer` service with `loadbalancer.openstack.org/floating-network-id`.
- Because the upstream Hermes container currently has an open dashboard bug in containerized deployments, this project includes an init-container workaround that builds the dashboard assets into a writable volume before starting the gateway.

## Validation workflow

1. Enter the project:

   ```sh
   cd ~/Documents/Personnal/Development/Projects/Personnal/test-hermes
   ```

2. Prepare local auth:

   ```sh
   chmod 600 clouds.yaml
   export OS_CLIENT_CONFIG_FILE="$PWD/clouds.yaml"
   export OS_CLOUD=tenant
   ```

3. Fill the application credential ID and secret into `clouds.yaml`.

4. Test OpenStack auth and required objects:

   ```sh
   openstack token issue
   openstack coe cluster template show k8s-capi-helm-ubuntu-v1.34.7
   openstack image show ubuntu-jammy-kube-v1.34.7
   openstack flavor show m1.2xlarge
   openstack flavor show m1.medium
   openstack coe nodegroup list hermes-test || true
   ```

5. Prepare Terraform:

   ```sh
   terraform init
   terraform fmt
   terraform validate
   terraform plan
   ```

6. If the plan is sane, apply it:

   ```sh
   terraform apply
   ```

   Important note:
   on this cloud, the OpenStack provider can return a false Magnum waiter error even when the cluster is still progressing normally. If that happens, inspect `openstack coe cluster show hermes-test -f yaml`, wait for `CREATE_COMPLETE`, and then run:

   ```sh
   terraform apply -refresh-only
   ```

7. Use the Terraform-generated kubeconfig:

   ```sh
   export KUBECONFIG="$PWD/generated/kubeconfig/config"
   kubectl get nodes -o wide -L hermes.openstack.org/gemma4
   kubectl -n hermes get pods -o wide
   kubectl -n hermes get svc
   ```

8. Wait for the public dashboard address:

   ```sh
   kubectl -n hermes get svc hermes-dashboard-public -w
   ```

   When `EXTERNAL-IP` is assigned, open:

   - dashboard: `http://<EXTERNAL-IP>`

9. Optional local-only access to both dashboard and API:

   ```sh
   kubectl -n hermes port-forward svc/hermes 9119:9119 8642:8642
   ```

   Then open:

   - dashboard: `http://127.0.0.1:9119`
   - Hermes API server: `http://127.0.0.1:8642/v1`

10. Verify Gemma connectivity from inside Hermes:

   ```sh
   kubectl -n hermes exec deploy/hermes -- curl -fsS http://gemma4:11434/api/tags
   kubectl -n hermes logs deploy/hermes --tail=50
   ```

11. If Ollama is up but `/api/tags` returns `{"models":[]}`, the service path is healthy and the model is still downloading into the PVC.

## Notes

- The Magnum cluster resource stores computed connection data in Terraform state as plain text. Treat `terraform.tfstate` as sensitive local data.
- This repository scaffolding does not assume any global `~/.config/openstack` files.
- The helper script defaults to `./clouds.yaml` through `OS_CLIENT_CONFIG_FILE`.
- `terraform destroy` removes the Magnum cluster managed by this project. It does not delete the validated public cluster template.
- Terraform is the source of truth for the Hermes bootstrap files placed in `/opt/data`. If you edit Hermes configuration live in the dashboard, those changes can be overwritten by the next rollout or pod restart.
- A failed Magnum create can leave `CREATE_FAILED` resources in both Terraform state and Magnum. Clean those up before retrying with a different credential.
- If apply reports something inconsistent during Magnum polling, check `openstack coe cluster show hermes-test -f yaml` for the real `status` and `status_reason`.
- If a new cluster fails very early with CAPI topology or ClusterClass errors, ask the cloud admin to confirm the `magnum-v0.36.6` ClusterClass `diskSetup` patch is still applied.
- If Cinder PVCs fail later with endpoint discovery or CSI startup errors, ask the cloud admin to confirm the Keystone compatibility alias still exists:
  - service name `cinderv3`
  - service type `volumev3`
- If a new cluster fails very early with CAPI topology or ClusterClass errors, ask the cloud admin to confirm the current Magnum CAPI Helm path is still healthy and the cluster class remains patched as expected.
- If Kubernetes comes up but `gemma4` stays `Pending`, confirm the dedicated `gemma4-large` nodegroup exists and that nodes carry label `magnum.openstack.org/nodegroup=gemma4-large`.
- If a dedicated Magnum nodegroup reports `CREATE_COMPLETE` but never gets a `stack_id`, `node_addresses`, or a Nova server, treat that as a cloud-side driver issue rather than a successful large-worker rollout.
- If the Hermes dashboard fails to start even with the init-container asset build, re-check the upstream open dashboard container bug before assuming the Terraform logic is wrong.
- If `service/hermes-dashboard-public` stays in `<pending>`, inspect `openstack-cloud-controller-manager` logs in `openstack-system` and verify the tenant can create Octavia load balancers and floating IPs on the `public` network.

## Cleanup

When you are done testing:

```sh
terraform destroy
rm -rf generated
```
