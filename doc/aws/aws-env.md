# aws-env: Wrapper for AWS temporary sessions using MFA and roles

This aims to be the "ultimate" AWS temporary session wrapper.  Highlights:

- Supports both MFA and assuming roles
- Caches credentials so you can share between shell sessions and don't get
  prompted for MFA codes unnecessarily
- Can be used either as a wrapper or `eval`'d
- Uses the same configuration files as the AWS CLI, with some extensions
- Supports directory context-sensitive configuration in `aws-env.config`
- Only non-standard dependency is the AWS CLI

To install the latest version, download from
https://raw.githubusercontent.com/fpco/devops-helpers/master/aws/aws-env.sh and
put it somewhere on your PATH with execute bits, preferably named `aws-env`.
For example:

    wget -O ~/bin/aws-env https://raw.githubusercontent.com/fpco/devops-helpers/master/aws/aws-env.sh
    chmod a+x ~/bin/aws-env

Usage
-----

    aws-env \
        [--help] \
        [--profile NAME|-p NAME] \
        [--role-arn ARN|-r ARN] \
        [--mfa-duration-seconds DURATION] \
        [--mfa-refresh-factor PERCENT] \
        [--role-duration-seconds DURATION] \
        [--role-refresh-factor PERCENT] \
        [COMMAND [ARGS ...]]

Options
-------

`--help`: Display this help text and exit.

`--profile NAME`: Set the AWS CLI profile to use. If not specified, uses the
  value of AWS_DEFAULT_PROFILE or `default` if that is not set.

`--role-arn ARN`: ARN of role to assume.  Overrides the profile's value.

`--mfa-duration-seconds DURATION`: Set how long until the MFA session expires.
  This defaults to the maximum 129600 (36 hours).

`--role-duration-seconds DURATION`: Set how long until the role session expires.
  This defaults to the maximum 3600 (1 hour).

`--role-refresh-factor PERCENT`: Percentage of role token duration at which to
  refresh it. The default is to request a new token after 35% of the old token's
  duration has passed.

`--mfa-refresh-factor PERCENT`: Percentage of MFA token duration at which to
  refresh it. The default is to request a new token after 65% of the old token's
  duration has passed.

Arguments
---------

When given a COMMAND, executes the command in the context of the temporary
session. For example:

    aws-env -p admin terraform plan

Without a COMMAND, prints `export` commands to stdout suitable for evaluating by
the shell. For example:

    eval $(aws-env -p admin)

Requirements
------------

You must have the AWS CLI installed. See
http://docs.aws.amazon.com/cli/latest/userguide/installing.html.

Configuration
-------------

aws-env gets configuration from two places:
- The AWS CLI configuration files, by default `~/.aws/config` and `~/.aws/credentials`.
- Its own `aws-env.config` and `aws-env.config`

### AWS CLI configuration file.

`~/.aws/credentials` must contain the initial credentials for connecting to AWS.
For example:

    [signin]
    aws_access_key_id=AKIA................
    aws_secret_access_key=BC/u....................................

`~/.aws/config` contains the MFA device ARN, role ARN and source
profile. For example:

    [profile admin]
    role_arn=arn:aws:iam::123456789000:role/admin
    mfa_serial=arn:aws:iam::987654321000:mfa/username
    source_profile=signin

See
http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
and http://docs.aws.amazon.com/cli/latest/userguide/cli-roles.html for more
details.

Some extensions are supported that the AWS CLI does not support:

- Any profile, even those without a `role_arn`, may specify an `mfa_serial`.
  That means that if you don't use roles, aws-env can still prompt you for an
  MFA code and set temporary credentials (unlike the AWS CLI). For example (in
  `~/.aws/config`)

        [profile signin]
        mfa_serial=arn:aws:iam::987654321000:mfa/username

- aws-env will use the `mfa_serial` from the `source_profile`, so you don't
  need to repeat it in every role profile.

### aws-env configuration

The optional aws-env configuration files are read from the following locations,
in order, with values in that come earlier overriding those that come later.

- Current directory's `.aws-env.config`
- Current directory's `aws-env.config`
- Recursively in the parent directories' `.aws-env.config` and
  `aws-env.config`s, until (and not including) /Users/manny or the root.
- `~/.aws-env.config`

Here's an example:

    profile=admin
    source_profile=signin
    role_arn=arn:aws:iam::123456789000:role/admin
    mfa_duration_seconds=43200
    role_duration_seconds=1800
    mfa_refresh_factor=50
    role_refresh_factor=10

The values correspond to the command-line options or AWS CLI configuration
options with the same names, so see the [Options](#options) section for details.
Command-line arguments override any configuration in the aws-env config.

A typical way to use this is to put an `aws-env.config` in the root of your
project that specifies the `role_arn` to assume when working on that project
the `source_profile` that has the credentials and MFA device, and commit that
to the repository. As long as all users of the project have a consistent name
for the credentials `source_profile`, they can just prefix any AWS-using
command with `aws-env` and be sure it's run in the correct context. Users can
add or override configuration locally using `.aws-env.config` (note: has a dot
at the beginning). It can also be nice to specify a `profile` which does not
actually have to exist, but means that `AWS_ENV_CURRENT_PROFILE` will be set
to that value for inclusion in the shell prompt. Example:

    profile=admin
    source_profile=signin
    role_arn=arn:aws:iam::123456789000:role/admin

Environment variables
---------------------

The following environment variables are read by aws-env:

`AWS_DEFAULT_PROFILE`: AWS CLI profile to use. Defaults to `default`.
`default` is used.

`AWS_CONFIG_FILE`: Location of the AWS CLI config file. Defaults to
`~/.aws/config`.

`AWS_ENV_CACHE_DIR`: Location of cached credentials. Defaults to
`~/.aws-env/`

The following standard AWS environment variables are **set** by aws-env:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`
- `AWS_SECURITY_TOKEN`
- `AWS_DEFAULT_REGION`

In addition, `AWS_ENV_CURRENT_PROFILE` is set to the name of the current
profile. This can be handy for including in your shell prompt. For example, add
this to your `.bashrc`:

    PS1='${AWS_ENV_CURRENT_PROFILE:+[$AWS_ENV_CURRENT_PROFILE]}'"$PS1"

File locations
--------------

By default, temporary credentials are stored in `~/.aws-env/`, AWS CLI
configuration is read from `~/.aws/config`, and aws-env configuration is read
from `~/.aws-env.config`.

