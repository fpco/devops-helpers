#!/usr/bin/env bash
#
# travis/setup_kubectl.sh: Install kubectl and the Kubernetes
# clusters' admin keys on Travis CI.
#
# This requires that 'travis encrypt-file` has been used to encrypt the admin keys.
#

if [[ $# != 1 ]]; then
    echo "Usage: ${BASH_SOURCE[0]} CLUSTERS-PATH" 2>&1
    exit 1
fi
set -xe
mkdir -p ~/.kube/clusters
cp -r "$(dirname "${BASH_SOURCE[0]}")"/clusters/* ~/.kube/clusters/
cd "$1"
cp -r . ~/.kube/clusters/
for x in `find . -name '*.encrypted_*'`; do
    set +x #Ensure that the keys aren't exposed in logs
    openssl aes-256-cbc \
        -K "$(eval "echo \$${x/#.*.encrypted_/encrypted_}_key")" \
        -iv "$(eval "echo \$${x/#.*.encrypted_/encrypted_}_iv")" \
        -in "$x" \
        -out ~/.kube/clusters/"${x/%.encrypted_*/}" -d
    set -x
done
mkdir -p ~/.local/bin
curl -o ~/.local/bin/kubectl \
    https://storage.googleapis.com/kubernetes-release/release/v1.1.2/bin/linux/amd64/kubectl
chmod a+x ~/.local/bin/kubectl
