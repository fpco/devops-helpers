aws-env: Wrapper for AWS temporary sessions using MFA and roles
===============================================================

Copyright (c) 2017 FP Complete Corp.  
Author and maintainer: Emanuel Borsboom <manny@fpcomplete.com>

This aims to be the "ultimate" AWS temporary session wrapper.  Highlights:

  - Supports both MFA and assuming roles
  - Caches credentials so you can share between shell sessions and don't get
    prompted for MFA codes unnecessarily
  - Can be used either as a wrapper or `eval`ed
  - Bash prompt integration: add profile to prompt in `eval` mode
  - Uses the same configuration files as the AWS CLI, with some extensions
  - Supports directory context-sensitive configuration in `aws-env.config`
  - Only non-standard dependency is the AWS CLI

Limitations

  - Only tested with `bash`.

Installation
------------

### Requirements

You must have the AWS CLI installed. See the [AWS CLI installation
guide](http://docs.aws.amazon.com/cli/latest/userguide/installing.html).

### Download and install

To install the latest version, download [the
script](https://raw.githubusercontent.com/fpco/devops-helpers/master/aws/aws-env.sh)
and put it somewhere on your PATH with execute bits, preferably named `aws-env`.
For example:

    wget -O aws-env https://raw.githubusercontent.com/fpco/devops-helpers/master/aws/aws-env.sh
    chmod a+x aws-env
    sudo mv aws-env /usr/local/bin/aws-env

Usage
-----

    aws-env \
        [--profile=NAME|-p NAME] \
        [--mfa-serial=ARN|-m ARN] \
        [--role-arn=ARN|-r ARN] \
        [--external-id=STRING|-e STRING] \
        [--federated|-f] \
        [--help] \
        [--] \
        [COMMAND [ARGS ...]]

### Options

`--profile NAME`: Set the AWS CLI profile to use. If not specified, uses the
    value of AWS_PROFILE or AWS_DEFAULT_PROFILE, or `default` if that is not set. Note that this
    will completely override any role_arn, mfa_serial, region, and
    source_profile set in the `aws-env.config`.

`--mfa-serial ARN`: Override or set the MFA device ARN.

`--role-arn ARN`: Override or set the ARN for the role to assume.

`--external-id STRING`: Set a optional required external ID for the subsequent assume role call.

`--federated`: Assume the given profile contains an active federated session (SAML, OpenID, ..).

`--help`: Display this help text and exit.

### Arguments

When given a COMMAND, executes the command in the context of the temporary
session. For example:

    aws-env -p admin terraform plan

Without a COMMAND, prints commands that set environment variables to stdout,
suitable for evaluating by the shell. For example:

    eval $(aws-env -p admin)

**Warning**: `eval` mode credentials will expire, and then it is up to you to
refresh them.  **This can be dangerous** because they might expire in the
middle of an operation, leading to potential data loss (like an incorrect
Terraform remote state file).  As such, we recommend avoiding this approach
and prefixing all commands with `aws-env` instead.

Bash integration
----------------

By default, `eval $(aws-env)` will add the current profile name to the bash
prompt (`$PS1`). The prompt format can be overridden in `.aws-env.config`.

Configuration Files
-------------------

aws-env gets configuration from two places (in addition to environment variables):

  - The AWS CLI configuration files, by default `~/.aws/config` and `~/.aws/credentials`.
  - Its own `aws-env.config` and `.aws-env.config`

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
    That means that even if you don't use roles, aws-env can still prompt you
    for an MFA code and set temporary credentials (unlike the AWS CLI). For
    example (in `~/.aws/config`)

        [profile signin]
        mfa_serial=arn:aws:iam::987654321000:mfa/username

  - aws-env will use the `mfa_serial` and `region` from the `source_profile`, so
    you don't need to repeat it in every role profile.

Note: the AWS CLI configuration file is ignored if the `AWS_ACCESS_KEY_ID`
environment variable is set.

### aws-env configuration

The optional aws-env configuration files are read from the following locations,
in order, with values in that come earlier overriding those that come later.

  - Current directory's `.aws-env.config`
  - Current directory's `aws-env.config`
  - Recursively in the parent directories' `.aws-env.config` and
    `aws-env.config`s, until (and not including) $HOME or the root.
  - `$HOME/.aws-env.config`

Here's an annotated example (all fields are optional, and defaults or values
from the AWS CLI configuration will be used for any ommitted values):

    # The default AWS region.
    region=us-west-2

    # Profile name. Note that this profile does not need to exist in the AWS CLI
    # configuration if a source_profile is set, but it is displayed to the user
    # and in the prompt.
    profile=admin

    # The AWS CLI profile to use when creating the temporary session.
    source_profile=signin

    # The ARN of the role to assume.
    role_arn=arn:aws:iam::123456789000:role/admin

    # How long until the MFA session expires. This defaults to the maximum
    # 129600 (36 hours).
    mfa_duration_seconds=43200

    # How long until the role session expires. This defaults to the maximum 3600
    # (1 hour).
    role_duration_seconds=1800

    # Percentage of MFA token duration at which to refresh it. The default is to
    # request a new token after 65% of the old token's duration has passed.
    mfa_refresh_factor=50

    # Percentage of role token duration at which to refresh it. The default is
    # to request a new token after 35% of the old token's duration has passed.
    role_refresh_factor=10

    # The 'printf' format for the profile in the bash prompt. This can include
    # terminal escape sequences to change the colour.  Defaults to '[%s]'
    prompt_format=\[\033[1;31m\](%s)\[\033[0m\]

A typical way to use this is to put an `aws-env.config` in the root of your
project that specifies the `role_arn` to assume when working on that project the
`source_profile` that has the credentials and MFA device, and commit that to the
repository. As long as all users of the project have a consistent name for the
credentials `source_profile`, they can just prefix any AWS-using command with
`aws-env` and be sure it's run in the correct context. Users can add or override
configuration locally using `.aws-env.config` (note: has a dot at the
beginning). It can also be nice to specify a `profile` which does not actually
have to exist, but means that will be displayed in the bash prompt. Example:

    region=us-west-2
    profile=admin
    source_profile=signin
    role_arn=arn:aws:iam::123456789000:role/admin

Environment variables
---------------------

### The following environment variables are read by aws-env:

`AWS_PROFILE` and `AWS_DEFAULT_PROFILE`: AWS CLI profile to use. Defaults to
`default`.

`AWS_CONFIG_FILE`: Location of the AWS CLI config file. Defaults to
`~/.aws/config`.

`AWS_ENV_CACHE_DIR`: Location of cached credentials. Defaults to
`~/.aws-env/`

`AWS_ENV_DEFAULT_MFA_SERIAL`: Default MFA device ARN to use if not
set in configuration file or on command-line.

`AWS_ENV_DEFAULT_ROLE_ARN`: Default ARN of role to assume if not
set in configuration file or on command-line.

`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`: Default AWS credentials to use
in order to generate temporary credentials. Note that if these are specified,
the AWS configuration files are ignored.

### The following standard AWS environment variables are **set** by aws-env:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`
- `AWS_SECURITY_TOKEN`
- `AWS_DEFAULT_REGION`

In addition, `AWS_ENV_CURRENT_PROFILE` is set to the name of the current
profile.

When used in `eval` mode, `PS1` is also prefixed so that the bash prompt
shows the current profile.

File locations
--------------

By default, temporary credentials are stored in `~/.aws-env/`, AWS CLI
configuration is read from `~/.aws/config`, and aws-env configuration is read
from `~/.aws-env.config`.
