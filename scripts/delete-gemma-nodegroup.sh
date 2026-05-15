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

if ! openstack --os-cloud "$OS_CLOUD" coe nodegroup show "$cluster_name" "$nodegroup_name" >/dev/null 2>&1; then
  echo "Nodegroup $nodegroup_name is already absent from cluster $cluster_name."
  exit 0
fi

openstack --os-cloud "$OS_CLOUD" coe nodegroup delete "$cluster_name" "$nodegroup_name"

while openstack --os-cloud "$OS_CLOUD" coe nodegroup show "$cluster_name" "$nodegroup_name" >/dev/null 2>&1; do
  echo "Waiting for nodegroup $nodegroup_name to delete"
  sleep 10
done

echo "Nodegroup $nodegroup_name deleted."
