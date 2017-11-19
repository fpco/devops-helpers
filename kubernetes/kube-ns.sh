#!/usr/bin/env bash
#
# This script makes dealing with Kubernetes namespaces a little bit more
# convenient. Basically you can use `eval $(kube-ns NAMESPACE)` to switch to a
# different namespace, or `kube-ns NAMESPACE COMMAND ARGS` to run the command in
# a different namespace.
#
# It copies the current kube config to a new file, changes the namespace in the
# ile's current context, and updates $KUBECONFIG to point to the new file.
#
# The advantage of this over using something like `alias
# kubectl='/usr/local/bin/kubectl --namespace NAMESPACE'` is that aliases aren't
# inherited by scripts, so a script that uses kubectl would ignore the namespace
# in the alias.
#
# Another way to achieve this sort of result might be to make a `kubectl`
# wrapper script and make sure it's on the PATH instead of the `kubectl` binary.
#
# The optional `--reset` argument will reset the environment to what it was
# beore kube-ns was used.  It can be used with eval or as a wrapper.
#

set -eu

if [[ -s "${KUBE_NS_ORIG_KUBECONFIG:-}" && "${KUBECONFIG:-}" == "${KUBE_NS_EXPECT_KUBECONFIG:-}" ]]; then
    export KUBECONFIG="$KUBE_NS_ORIG_KUBECONFIG"
else
    export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
fi
unset KUBE_NS_ORIG_KUBECONFIG
unset KUBE_NS_EXPECT_KUBECONFIG

if [[ $# -eq 0 ]]; then
    echo "$0: requires at least one argument" >&2
    exit 1
fi
if [[ "$1" == "--reset" ]]; then
    shift
    if [[ $# -gt 0 ]]; then
        exec "$@"
    else
        printf "export KUBECONFIG=%q;\n" "$KUBECONFIG"
        printf "unset KUBE_NS_ORIG_KUBECONFIG\n"
        printf "unset KUBE_NS_EXPECT_KUBECONFIG\n"
    fi
else
    NAMESPACE="$1"

    shift

    export KUBE_NS_ORIG_KUBECONFIG="$KUBECONFIG"
    export KUBECONFIG="${KUBECONFIG}_ns_${NAMESPACE}"
    export KUBE_NS_EXPECT_KUBECONFIG="${KUBECONFIG}"
    cat "$KUBE_NS_ORIG_KUBECONFIG" >"$KUBECONFIG"
    CONTEXT="$(kubectl config current-context)"
    kubectl config set-context "$CONTEXT" --namespace="$NAMESPACE" >/dev/null

    if [[ $# -gt 0 ]]; then
        exec "$@"
    else
        printf "export KUBECONFIG=%q;\n" "$KUBECONFIG"
        printf "export KUBE_NS_ORIG_KUBECONFIG=%q;\n" "$KUBE_NS_ORIG_KUBECONFIG"
        printf "export KUBE_NS_EXPECT_KUBECONFIG=%q;\n" "$KUBE_NS_EXPECT_KUBECONFIG"
    fi
fi
