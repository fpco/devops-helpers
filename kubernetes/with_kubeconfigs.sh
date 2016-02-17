#!/usr/bin/env bash
export KUBECONFIG
for KUBECONFIG in $KUBECONFIGS; do
    echo "KUBECONFIG=$KUBECONFIG" >&2
    "$@"
done
