#!/usr/bin/env bash
#
# kubernetes/deploy_rc_helper.sh: Perform a rolling update of an application
#
# REQUIRED ARGUMENTS:
#
#   ENV: Environment name (e.g. "prod" or "test")
#
#   --repo REPO: Docker image repository containing image to update to
#
#   --specdir PATH: Directory containing app's replication controller specification
#       ('APP-ENV-rc.yaml')
#
#   --app APP: Prefix of label of application to update
#
# OPTIONAL ARGUMENTS
#
#   --clusters PATH [PATH ...]: Path(s) to kubeconfigs for the cluster(s) to
#       update.  Required unless DEPLOY_KUBE_CLUSTERS is set.
#
#   --tag TAG: Tag of the image to deploy.
#       Default is the first tag returned by ../docker/default_tags.sh
#
# ENVIRONMENT VARIABLES
#
#   DEPLOY_KUBE_CLUSTERS: default value for '--clusters'
#

# Parse arguments

APP0=
REPO=
SPECDIR=
CLUSTERS="$DEPLOY_KUBE_CLUSTERS"
TAG=
ENV=
while [[ $# > 0 ]]; do
    case "$1" in
        --repo)
            REPO="$2"
            shift
            ;;
        --tag)
            TAG="$2"
            shift
            ;;
        --specdir)
            SPECDIR="$2"
            shift
            ;;
        --clusters)
            CLUSTERS=""
            while [[ $# > 1  && $2 != -* && $2 == */* ]]; do
                CLUSTERS="$CLUSTERS $2"
                shift
            done
            ;;
        --app)
            APP0="$2"
            shift
            ;;
        *)
            if [[ "$1" == --* || -n "$ENV" ]]; then
                echo "Usage: ${BASH_SOURCE[0]} ENV --app APP --repo IMAGE_REPO --specdir PATH --clusters PATH [PATH ..] [--tag IMAGE_TAG]" >&2
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
if [[ -z "$APP0" ]]; then
    echo "${BASH_SOURCE[0]}: must specify --app" >&2
    exit 1
fi
if [[ -z "$REPO" ]]; then
    echo "${BASH_SOURCE[0]}: must specify --repo" >&2
    exit 1
fi
if [[ -z "$SPECDIR" ]]; then
    echo "${BASH_SOURCE[0]}: must specify --specdir" >&2
    exit 1
fi
if [[ -z "$CLUSTERS" ]]; then
    echo "${BASH_SOURCE[0]}: must specify --clusters" >&2
    exit 1
fi

set -xe

# Determine Docker image repo/tag and replication controller name

[[ -n "$TAG" ]] || TAG="$("$(dirname "${BASH_SOURCE[0]}")/../docker/default_tags.sh" "$ENV"|head -1)"
VER="${TRAVIS_BUILD_NUMBER:-${BUILD_NUMBER:-$(date +%Y%m%d%H%M%S)}}"
REPOTAG="$REPO:$TAG"
APPENV="$APP0-$ENV"
RC="$APPENV-v$VER"

# Update the replication controller spec file

TEMPSPEC="$(mktemp /tmp/spec.yaml.XXXXXX)"
sed -E \
    -e "s@^( *name: )$APPENV-v[0-9]*\$@\1$RC@" \
    -e "s@^( *version: )v[0-9]*\$@\1v$VER@" \
    -e "s@^( *image: )$REPO:.*\$@\1$REPOTAG@" \
    "$SPECDIR/$APPENV-rc.yaml" \
    | tee "$TEMPSPEC"

# Update each cluster in turn

for KUBECONFIG in $CLUSTERS; do
    export "KUBECONFIG=$KUBECONFIG"

    # Find the old replication controller

    OLDRC="$(kubectl get rc -o name -l "app=$APPENV" | sed 's/.*\///')"
    if [[ -n $OLDRC ]]; then

        # Perform a rolling update, replacing the old replication controller
        # with the new spec.

        kubectl rolling-update "$OLDRC" -f "$TEMPSPEC"
    else

        # No existing replication controller found; create a new one

        kubectl create -f "$TEMPSPEC"
    fi
done

# Send notification of successful update to Slack, if running under Travis CI

set +x # Don't print command, so that webhook secret doesn't appear in output
[[ -n "$SLACK_SEND_WEBHOOK" && "$TRAVIS" == "true" ]] && \
    curl -X POST --data-urlencode \
         'payload={"attachments": [{"color": "good", "pretext": "'"$APPENV deployed"'", "fields": [{"title": "Docker image", "value": "'"$REPOTAG"'", "short": false}, {"title": "Git repo/commit", "value": "'"${TRAVIS_REPO_SLUG}@${TRAVIS_BRANCH} (${TRAVIS_COMMIT})"'", "short": false}]}], "channel": "#code_push", "username": "Kubernetes", "icon_emoji": ":kube:"}' \
         "$SLACK_SEND_WEBHOOK"
set -x

rm -f "$TEMPSPEC"
