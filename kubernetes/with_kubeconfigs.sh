#!/usr/bin/env bash
# Run a command in parallel for multiple Kubernetes clusters.
# Set the KUBECONFIG environment variable to a space-separated list
# of paths to `kubeconfig` files.
exec parallel echo KUBECONFIG={}\; export KUBECONFIG={}\; $@ ::: $KUBECONFIGS
