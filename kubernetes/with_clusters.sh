#!/usr/bin/env bash
# Run a command in parallel for multiple Kubernetes clusters.
# Set the DEPLOY_KUBE_CLUSTERS environment variable to a space-separated list
# of paths to `kubeconfig` files.
exec parallel echo KUBECONFIG={}\; export KUBECONFIG={}\; $@ ::: $DEPLOY_KUBE_CLUSTERS
