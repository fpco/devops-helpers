#!/usr/bin/env bash

show_help() {
  cat <<EOF

$(basename "${BASH_SOURCE[0]}"): determine tags to give image

If building under Travis CI, gives the image three tags:
  - REPO:[TAG_]BRANCH[_pr-PULLREQUEST]_build-BUILDNUMBER
  - REPO:[TAG_]BRANCH[_pr-PULLREQUEST]
  - REPO:[TAG]

If building under Jenkins CI, gives the image two tags:
  - REPO:[TAG_]_build-BUILDNUMBER
  - REPO:[TAG]

If not building under a CI system, gives the image two tags:
  - REPO:[TAG_]commit-COMMITID[-dirty]
  - REPO:[TAG]

USAGE
-----

$(basename "${BASH_SOURCE[0]}") [-1|--one] [--tag TAG] REPO

REQUIRED ARGUMENTS
------------------

REPO: Name of Docker repository

OPTIONAL ARGUMENTS
------------------

-1|--one: only emit the most specific tag

--tag: add a prefix to the specific tags, and use TAG instead of 'latest'
EOF
}

ONE=0
TAG=
REPO=
while [[ $# > 0 ]]; do
    case "$1" in
        -1)
            ONE=1
            ;;
        --one)
            ONE=1
            ;;
        --tag)
            TAG="$2"
            shift
            ;;
        *)
            if [[ "$1" == --* || -n "$REPO" ]]; then
                echo "${BASH_SOURCE[0]}: invalid argument: $1" >&2
                show_help
                exit 1
            else
                REPO="$1"
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

if [[ $TRAVIS == true ]]; then
    echo "${REPO}:${TRAVIS_BRANCH//[^A-Za-z0-9_.-]/_}$([[ $TRAVIS_PULL_REQUEST == false ]] || echo _pr-${TRAVIS_PULL_REQUEST})_build-${TRAVIS_BUILD_NUMBER}"
    if [[ $ONE == 0 ]]; then
        t="${TRAVIS_BRANCH//[^A-Za-z0-9_.-]/_}$([[ $TRAVIS_PULL_REQUEST == false ]] || echo _pr-${TRAVIS_PULL_REQUEST})"
        [[ "$t" == "${TAG:-latest}" ]] || echo "${REPO}:${t}"
    fi
elif [[ -n $JENKINS_HOME ]]; then
    echo "${REPO}:${TAG}${TAG:+_}build-${BUILD_NUMBER}"
else
    dirty="$(git status --porcelain)"
    echo "${REPO}:${TAG}${TAG:+_}commit-$(git rev-parse HEAD)${dirty:+-dirty}"
fi
[[ $ONE == 1 ]] || echo "${REPO}:${TAG:-latest}"
