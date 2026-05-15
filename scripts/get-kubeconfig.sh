#!/usr/bin/env sh
set -eu

OS_CLIENT_CONFIG_FILE=${OS_CLIENT_CONFIG_FILE:-$PWD/clouds.yaml}
OS_CLOUD=${OS_CLOUD:-tenant}

if [ "$#" -gt 0 ]; then
  cluster_name=$1
else
  cluster_name=$(terraform output -raw cluster_name)
fi

if [ -z "$cluster_name" ]; then
  echo "Cluster name is empty. Pass it explicitly or apply Terraform first." >&2
  exit 1
fi

mkdir -p ./generated/kubeconfig
rm -f ./generated/kubeconfig/config

openstack --os-cloud "$OS_CLOUD" coe cluster config "$cluster_name" --dir ./generated/kubeconfig
