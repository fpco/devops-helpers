# devops-helpers

Open-source devops helper scripts shared between projects.

These helper scripts are not normally used directly, but instead wrapped
with default arguments for specific projects.

## Wrappers

Typically, projects will have the following wrappers:

* `etc/build-deploy.sh prod`: build the code, push a Docker image, and
  rolling-update the production clusters
* `etc/docker/build.sh`: build a Docker image (gives it the `latest` tag)
* `etc/docker/push.sh prod [--tag TAG]`: push the local `latest` image to the
  Docker registry with `prod` and `prod_COMMITID` tags
* `etc/kubernetes/deploy_rc.sh prod`: rolling-update the production clusters to the image with tag `prod_COMMITID`

When run from CI systems (Travis or Jenkins) the tags are a bit different;
see `docker/default_tags.sh` for details.
