#!/usr/bin/env sh
set -eu

OS_CLIENT_CONFIG_FILE=${OS_CLIENT_CONFIG_FILE:-$PWD/clouds.yaml}
OS_CLOUD=${OS_CLOUD:-tenant}

if [ "$#" -gt 0 ]; then
  cluster_name=$1
else
  cluster_name=$(terraform output -raw cluster_name)
fi

if [ "$#" -gt 1 ]; then
  nodegroup_name=$2
else
  nodegroup_name=$(terraform output -raw gemma_nodegroup_name)
fi

if [ "$#" -gt 2 ]; then
  nodegroup_flavor=$3
else
  nodegroup_flavor=$(terraform output -raw gemma_worker_flavor)
fi

if [ "$#" -gt 3 ]; then
  nodegroup_count=$4
else
  nodegroup_count=$(terraform output -raw gemma_worker_count)
fi

nodegroup_image=$(terraform output -raw magnum_image_id 2>/dev/null || true)
if [ -z "$nodegroup_image" ]; then
  nodegroup_image=$(openstack --os-cloud "$OS_CLOUD" image show ubuntu-jammy-kube-v1.34.7 -f value -c id)
fi

if openstack --os-cloud "$OS_CLOUD" coe nodegroup show "$cluster_name" "$nodegroup_name" >/dev/null 2>&1; then
  echo "Nodegroup $nodegroup_name already exists in cluster $cluster_name."
else
  openstack --os-cloud "$OS_CLOUD" coe nodegroup create \
    --flavor "$nodegroup_flavor" \
    --image "$nodegroup_image" \
    --node-count "$nodegroup_count" \
    "$cluster_name" \
    "$nodegroup_name"
fi

empty_realization_checks=0

while :; do
  status=$(openstack --os-cloud "$OS_CLOUD" coe nodegroup show "$cluster_name" "$nodegroup_name" -f value -c status)
  node_addresses=$(openstack --os-cloud "$OS_CLOUD" coe nodegroup show "$cluster_name" "$nodegroup_name" -f value -c node_addresses)
  stack_id=$(openstack --os-cloud "$OS_CLOUD" coe nodegroup show "$cluster_name" "$nodegroup_name" -f value -c stack_id)
  case "$status" in
    CREATE_COMPLETE)
      if [ -n "$stack_id" ] || [ -n "$node_addresses" ]; then
        echo "Nodegroup $nodegroup_name is ready."
        break
      fi
      empty_realization_checks=$((empty_realization_checks + 1))
      if [ "$empty_realization_checks" -ge 6 ]; then
        echo "Nodegroup $nodegroup_name reported CREATE_COMPLETE without any backing nodes." >&2
        openstack --os-cloud "$OS_CLOUD" coe nodegroup show "$cluster_name" "$nodegroup_name" -f yaml >&2
        exit 1
      fi
      echo "Nodegroup $nodegroup_name is CREATE_COMPLETE but still has no backing nodes yet"
      sleep 15
      ;;
    CREATE_FAILED|DELETE_FAILED|UPDATE_FAILED)
      echo "Nodegroup $nodegroup_name ended in $status." >&2
      openstack --os-cloud "$OS_CLOUD" coe nodegroup show "$cluster_name" "$nodegroup_name" -f yaml >&2
      exit 1
      ;;
    *)
      echo "Waiting for nodegroup $nodegroup_name: $status"
      sleep 15
      ;;
  esac
done
