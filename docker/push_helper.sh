#!/usr/bin/env bash
#
# docker/push_helper.sh: tag and push a Docker image
#
# REQUIRED ARGUMENTS:
#
# ENV: Environment name (e.g. "prod" or "test")
#
# --repo REPO: Name of the Docker image repository to build
#
# OPTIONAL ARGUMENTS:
#
# --image ID: Source image to push.  Defaults to 'REPO:latest'.
#
# --tags TAG [TAG ..]: Tag(s) to give the image when pushing.
#     See default_tags.sh for the default values.
#

# Parse arguments

IMAGE=
REPO=
TAGS=
ENV=
while [[ $# > 0 ]]; do
    case "$1" in
        --image)
            IMAGE="$2"
            shift
            ;;
        --repo)
            REPO="$2"
            shift
            ;;
        --tags)
            while [[ $# > 1  && $2 != -* ]]; do
                TAGS="$TAGS $2"
                shift
            done
            ;;
        *)
            if [[ "$1" == --* || -n "$ENV" ]]; then
                echo "Usage: ${BASH_SOURCE[0]} ENV --repo IMAGE_REPO [--tags TAG [TAG ..]] [--image IMAGE_ID]" >&2
                exit 1
            else
                ENV="$1"
            fi
            ;;
    esac
    shift
done
if [[ -z "$ENV" ]]; then
    echo "${BASH_SOURCE[0]}: must specify ENV" >&2
    exit 1
fi
if [[ -z "$REPO" ]]; then
    echo "${BASH_SOURCE[0]}: must specify --repo" >&2
    exit 1
fi
set -xe
[[ -n "$IMAGE" ]] || IMAGE="$REPO:latest"
if [[ -n "$TAGS" ]]; then
    TAGS="$ENV $TAGS"
else
    TAGS="$("$(dirname "${BASH_SOURCE[0]}")/default_tags.sh" "$ENV")"
fi

# Log into registry

set +x # Don't print docker login command, so that password isn't in output
[[ -n "$DOCKER_USERNAME" && -n "$DOCKER_PASSWORD" ]] && \
    docker login -e="$DOCKER_EMAIL" -u="$DOCKER_USERNAME" -p="$DOCKER_PASSWORD"
set -x

# Tag and push the image

for tag in $TAGS; do
    if [[ "$REPO:$tag" != "$IMAGE" ]]; then
        docker tag -f "$IMAGE" "$REPO:$tag"
    fi
    docker push "$REPO:$tag"
done
