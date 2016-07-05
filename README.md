# devops-helpers

Open-source devops helper scripts shared between projects. These helper scripts
are not normally used directly, but instead wrapped with default arguments for
specific projects.

## Wrappers

Typically, projects will have the following wrappers:

* `etc/build_deploy.sh ENV`: build the code, push a Docker image, and
  rolling-update the replication controllers on all clusters.
* `etc/docker/build.sh`: build a Docker image (gives it the `latest` tag)
* `etc/docker/push.sh ENV [--tags TAG [TAG ..]]`: push the local `latest` image
  to the Docker registry with `ENV` tag. If TAG(s) specified, also pushes with
  those tags, otherwise defaults to `ENV_COMMITID`.
* `etc/kubernetes/deploy_rc.sh ENV [--tag TAG]`: rolling-update the replication
  controllers on all clusters to the image with tag `ENV_COMMITID` (or TAG if
  specified)

ENV specifies the environment name, and will be a value like `prod`, `stag`, or
`test`.

When run from CI systems (Travis or Jenkins) the default tags are a bit
different; see `docker/default_tags.sh` for details.
