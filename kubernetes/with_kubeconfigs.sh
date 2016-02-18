#!/usr/bin/env bash
parallel echo KUBECONFIG={}\; export KUBECONFIG={}\; $@ ::: $KUBECONFIGS
