#!/usr/bin/env bash
#
# docker/default_tags.sh: Determine default tags to give images
#
# OPTIONAL ARGUMENTS:
#
# ENV: Environment name (e.g. "prod" or "test").  Defaults to "latest".
#
# If building under Travis CI, gives the image three tags:
#   - :BRANCH[_PULLREQUEST][_BUILDNUMBER]_COMMITID
#   - :BRANCH[_PULLREQUEST]_COMMITID
#   - :ENV
# For the latter, if the branch is 'master' and there is no pull request, the
# second tag is set to 'latest' instead of 'master'.
#
# If building under Jenkins CI, gives the image two tags:
#   - :ENV[_BUILDNUMBER]_COMMITID
#   - :ENV
#
# If not building under a CI system, gives the image two tags:
#   - :ENV_COMMITID[-dirty]
#   - :ENV
#

ENV="$1"; shift
if [[ $TRAVIS == true ]]; then
    echo "${TRAVIS_BRANCH//[^A-Za-z0-9_.-]/_}$([[ $TRAVIS_PULL_REQUEST == false ]] || echo _${TRAVIS_PULL_REQUEST})_${TRAVIS_BUILD_NUMBER}_${TRAVIS_COMMIT}"
    t="$(if [[ $TRAVIS_BRANCH == master && $TRAVIS_PULL_REQUEST == false ]]; then echo latest; else echo ${TRAVIS_BRANCH//[^A-Za-z0-9_.-]/_}; fi)$([[ $TRAVIS_PULL_REQUEST == false ]] || echo _${TRAVIS_PULL_REQUEST})"
    [[ "$t" == "$ENV" ]] || echo "$t"
elif [[ -n $JENKINS_HOME ]]; then
    echo "${ENV}_${BUILD_NUMBER}_$(git rev-parse HEAD)"
else
    dirty="$(git status --porcelain)"
    echo "${ENV}_$(git rev-parse HEAD)${dirty:+-dirty}"
fi
echo "${ENV:-latest}"
