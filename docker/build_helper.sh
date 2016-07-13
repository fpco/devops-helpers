#!/usr/bin/env bash
set -e

show_help() {
    cat <<EOF

$(basename "${BASH_SOURCE[0]}"): build, tag and optionally push and deploya Docker image

USAGE
-----

$(basename "${BASH_SOURCE[0]}") [--push] [--no-build] [--kube-deploy DEPLOYMENT CONTAINER]
    [--tag TAG] REPO

REQUIRED ARGUMENTS
------------------

REPO: Name of Docker repository to build/push/deploy

OPTIONAL ARGUMENTS
------------------

--no-build: Don't build the image (pointless without --push or --kube-deploy)

--push: Push the image to a Docker registry after building

--kube-deploy: Update a Kubernetes Deployment with the new image after pushing
    (implies --push)

--tag: Tag to give the image.  See `tags.sh` for how image tags are
    generated.

EOF
}

# Parse arguments

BUILD=1
PUSH=0
KUBE_DEPLOYMENT=
KUBE_CONTAINER=
TAG=
REPO=
while [[ $# > 0 ]]; do
    case "$1" in
        --push)
             PUSH=1
             ;;
        --no-build)
             BUILD=0
             ;;
        --kube-deploy)
             KUBE_DEPLOYMENT="$2"
             KUBE_CONTAINER="$3"
             PUSH=1
             shift; shift
             ;;
        --tag)
            TAG="$2"
            shift
            ;;
        *)
            if [[ "$1" == -* || -n "$REPO" ]]; then
                echo "${BASH_SOURCE[0]}: invalid argument: $1" >&2
                show_help
                exit 1
            else
                REPO="$1"
                shift
                break
            fi
            ;;
    esac
    shift
done
if [[ -z "$REPO" ]]; then
    echo "${BASH_SOURCE[0]}: must specify REPO" >&2
    show_help
    exit 1
fi
TAGS="$("$(dirname "${BASH_SOURCE[0]}")/tags.sh" --tag "$TAG" "$REPO")"
FIRST_TAG="$("$(dirname "${BASH_SOURCE[0]}")/tags.sh" -1 --tag "$TAG" "$REPO")"

# Build and tag the image
if [[ $BUILD == 1 ]]; then
    echo
    echo ">>> Building '$FIRST_TAG'"
    docker build -t "$FIRST_TAG" "$@"
fi

for tag in $TAGS; do
    if [[ "$tag" != "$FIRST_TAG" ]]; then
        echo
        echo ">>> Tagging with '$tag'"
        docker tag -f "$FIRST_TAG" "$tag"
    fi
done

if [[ $PUSH == 1 ]]; then
    # Push the image tags
    for tag in $TAGS; do
        echo
        echo ">>> Pushing '$tag'"
        docker push "$tag"
    done
fi

if [[ -n "$KUBE_DEPLOYMENT" ]]; then
    # Rollout the image to a Kubernetes replica set
    echo
    echo ">>> Deploying to Kubernetes deployment '$KUBE_DEPLOYMENT'"
    kubectl set image deployment/"$KUBE_DEPLOYMENT" "$KUBE_CONTAINER"="$FIRST_TAG"
    kubectl rollout status deployment/"$KUBE_DEPLOYMENT"
fi
