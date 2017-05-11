#!/usr/bin/env bash
show_help() { cat <<'EOF'
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
        [--help] \
        [--] \
        [COMMAND [ARGS ...]]

### Options

`--profile NAME`: Set the AWS CLI profile to use. If not specified, uses the
    value of AWS_DEFAULT_PROFILE or `default` if that is not set. Note that this
    will completely override any role_arn, mfa_serial, region, and
    source_profile set in the `aws-env.config`.

`--mfa-serial ARN`: Override or set the MFA device ARN.

`--role-arn ARN`: Override or set the ARN for the role to assume.

`--help`: Display this help text and exit.

### Arguments

When given a COMMAND, executes the command in the context of the temporary
session. For example:

    aws-env -p admin terraform plan

Without a COMMAND, prints commands that set environment variables to stdout,
suitable for evaluating by the shell. For example:

    eval $(aws-env -p admin)

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

`AWS_DEFAULT_PROFILE`: AWS CLI profile to use. Defaults to `default`.
`default` is used.

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

EOF
}

set -eu

#
# Functions
#

# 'cleanup' cleans up after the script exits. This is called automatically by
# 'trap'.
cleanup() {
    [[ -z "$CRED_TEMP" ]] || rm -f "$CRED_TEMP"
    [[ -z "$EXPIRE_TEMP" ]] || rm -f "$EXPIRE_TEMP"
}

# 'configfield FILE FIELDNAME [SECTION]' reads the value of a field from a
# config file. If SECTION is included, reads that field from the given section
# (otherwise, reads the first in the file regardless of section).
configfield() {
    if [[ -n "${3:-}" ]]; then
        sed -ne '/^\['"$3"'\]/,/^\[/p' "$1" \
            |grep '^'"$2"'[[:space:]]*=' \
            |head -1 \
            |sed 's/^.*=[[:space:]]*//'
    else
        grep "^$2"'[[:space:]]*=' "$1" \
            |head -1 \
            |sed 's/^.*=[[:space:]]*//'
    fi
}

# 'load_cred_vars FILEPATH' set AWS_* environment variables from a credentials
# JSON file output by 'aws sts'.
load_cred_vars() {
    AWS_ACCESS_KEY_ID="$(grep AccessKeyId "$1"|sed 's/.*: "\(.*\)".*/\1/')"
    AWS_SECRET_ACCESS_KEY="$(grep SecretAccessKey "$1"|sed 's/.*: "\(.*\)".*/\1/')"
    AWS_SESSION_TOKEN="$(grep SessionToken "$1"|sed 's/.*: "\(.*\)".*/\1/')"
    AWS_SECURITY_TOKEN="$AWS_SESSION_TOKEN"
}

# 'load_env_config FILEPATH' set configuration variables from an aws-env config
# file if they are not already set.
load_env_config() {
    if [[ -s "$1" ]]; then
        [[ -n "$FIRST_ENV_CONFIG_FILE" ]] || FIRST_ENV_CONFIG_FILE="$1"
        if [[ -z "$PROFILE" ]]; then
            PROFILE="$(configfield "$1" profile)"
            [[ -z "$PROFILE" ]] || PROFILE_SOURCE_CONFIG="$1"
        fi
        [[ -n "$SRC_PROFILE" ]] || SRC_PROFILE="$(configfield "$1" source_profile)"
        if [[ -z "$ROLE_ARN" ]]; then
            ROLE_ARN="$(configfield "$1" role_arn)"
            [[ -z "$ROLE_ARN" ]] || ROLE_ARN_SOURCE_CONFIG="$1"
        fi
        [[ -n "$REGION" ]] || \
            REGION="$(configfield "$1" region)"
        [[ -n "$MFA_DURATION" ]] || \
            MFA_DURATION="$(configfield "$1" mfa_duration_seconds)"
        [[ -n "$ROLE_DURATION" ]] || \
            ROLE_DURATION="$(configfield "$1" role_duration_seconds)"
        [[ -n "$MFA_REFRESH" ]] || \
            MFA_REFRESH="$(configfield "$1" mfa_refresh_factor)"
        [[ -n "$ROLE_REFRESH" ]] || \
            ROLE_REFRESH="$(configfield "$1" role_refresh_factor)"
        [[ -n "$PROMPT_FORMAT" ]] || \
            PROMPT_FORMAT="$(configfield "$1" prompt_format)"
    fi
}

# 'setup_shell_prompt' modifies the bash prompt environment variables for
# inclusion of the profile name.
# TODO: support other shells besides 'bash'
setup_shell_prompt() {
    # Record and reset shell prompt variables to original values
    echo "if [ -z \${AWS_ENV_ORIG_PS1+x} ]; then export AWS_ENV_ORIG_PS1=\"\$PS1\"; else PS1=\"\$AWS_ENV_ORIG_PS1\"; fi;"

    # Add the current profile to PS1
    [[ -z "$PROMPT_FORMAT" ]] || \
        echo "case \"\$PS1\" in *AWS_ENV_CURRENT_PROFILE*) ;; *) PS1='\${AWS_ENV_CURRENT_PROFILE:+$(printf "$PROMPT_FORMAT" "\$AWS_ENV_CURRENT_PROFILE")}'"\$AWS_ENV_ORIG_PS1" ;; esac;"
}

#
# Set initial variable values
#

CURDATE="$(date +%s)"
ORIG_ARGS=("$@")
CRED_TEMP=
EXPIRE_TEMP=

#
# Ensure temporary files are cleaned up when aws-env exits.
#

trap cleanup EXIT

#
# Read aws-env.configs
#

FIRST_ENV_CONFIG_FILE=
ROLE_ARN=
ROLE_ARN_SOURCE_CONFIG=
MFA_SERIAL=
PROFILE=
PROFILE_SOURCE_CONFIG=
SRC_PROFILE=
REGION=
MFA_DURATION=
ROLE_DURATION=
MFA_REFRESH=
ROLE_REFRESH=
PROMPT_FORMAT=
pushd . >/dev/null
while [[ "$PWD" != "/" && "$PWD" != "$HOME" ]]; do
    load_env_config "$PWD/.aws-env.config"
    load_env_config "$PWD/aws-env.config"
    cd ..
done
popd >/dev/null
load_env_config "$HOME/.aws-env.config"

#
# Defaults
#

[[ -n "$MFA_DURATION" ]] || MFA_DURATION=129600
[[ -n "$ROLE_DURATION" ]] || ROLE_DURATION=3600
[[ -n "$MFA_REFRESH" ]] || MFA_REFRESH=65
[[ -n "$ROLE_REFRESH" ]] || ROLE_REFRESH=35
CACHE_DIR="${AWS_ENV_CACHE_DIR:-$HOME/.aws-env}"
[[ -n "$PROFILE" ]] || PROFILE="${AWS_DEFAULT_PROFILE:-default}"
AWS_CONFIG_FILE="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
[[ -n "$PROMPT_FORMAT" ]] || PROMPT_FORMAT='[%s]'
[[ -n "$MFA_SERIAL" ]] || MFA_SERIAL="${AWS_ENV_DEFAULT_MFA_SERIAL:-}"
[[ -n "$ROLE_ARN" ]] || ROLE_ARN="${AWS_ENV_DEFAULT_ROLE_ARN:-}"

#
# Parse command-line
#

PROFILE_ARG=
MFA_SERIAL_ARG=
ROLE_ARN_ARG=
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile=*)
            PROFILE_ARG="${1#--profile=}"
            shift
            ;;
        --profile)
            PROFILE_ARG="$2"
            shift 2
            ;;
        -p)
            PROFILE_ARG="$2"
            shift 2
            ;;
        --mfa-serial=*)
            MFA_SERIAL_ARG="${1#--mfa-serial=}"
            shift
            ;;
        --mfa-serial)
            MFA_SERIAL_ARG="$2"
            shift 2
            ;;
        -m)
            MFA_SERIAL_ARG="$2"
            shift 2
            ;;
        --role-arn=*)
            ROLE_ARN_ARG="${1#--role-arn=}"
            shift
            ;;
        --role-arn)
            ROLE_ARN_ARG="$2"
            shift 2
            ;;
        -r)
            ROLE_ARN_ARG="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "[$(basename "$0")] Invalid argument: $1" >&2
            echo "Run '$(basename "$0") --help' for usage information." >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

if [[ -n "$PROFILE_ARG" ]]; then
    PROFILE="$PROFILE_ARG"
    # Reset values read from config file, so that they're read from the profile instead
    PROFILE_SOURCE_CONFIG=
    ROLE_ARN=
    ROLE_ARN_SOURCE_CONFIG=
    SRC_PROFILE=
    REGION=
fi

[[ -z "$MFA_SERIAL_ARG" ]] || MFA_SERIAL="$MFA_SERIAL_ARG"
[[ -z "$ROLE_ARN_ARG" ]] || ROLE_ARN="$ROLE_ARN_ARG"

#
# Reset credentials environment variables to their original values.
#

case "${AWS_ENV_ORIG_ACCESS_KEY_ID:-}" in
    -) unset AWS_ACCESS_KEY_ID ;;
    "") ;;
    *) AWS_ACCESS_KEY_ID="${AWS_ENV_ORIG_ACCESS_KEY_ID}" ;;
esac
AWS_ENV_ORIG_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:--}"
case "${AWS_ENV_ORIG_SECRET_ACCESS_KEY:-}" in
    -) unset AWS_SECRET_ACCESS_KEY ;;
    "") ;;
    *) AWS_SECRET_ACCESS_KEY="${AWS_ENV_ORIG_SECRET_ACCESS_KEY}" ;;
esac
AWS_ENV_ORIG_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:--}"
case "${AWS_ENV_ORIG_SESSION_TOKEN:-}" in
    -) unset AWS_SESSION_TOKEN ;;
    "") ;;
    *) AWS_SESSION_TOKEN="${AWS_ENV_ORIG_SESSION_TOKEN}" ;;
esac
AWS_ENV_ORIG_SESSION_TOKEN="${AWS_SESSION_TOKEN:--}"
case "${AWS_ENV_ORIG_SECURITY_TOKEN:-}" in
    -) unset AWS_SECURITY_TOKEN ;;
    "") ;;
    *) AWS_SECURITY_TOKEN="${AWS_ENV_ORIG_SECURITY_TOKEN}" ;;
esac
AWS_ENV_ORIG_SECURITY_TOKEN="${AWS_SECURITY_TOKEN:--}"
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN
export AWS_ENV_ORIG_ACCESS_KEY_ID AWS_ENV_ORIG_SECRET_ACCESS_KEY AWS_ENV_ORIG_SESSION_TOKEN AWS_ENV_ORIG_SECURITY_TOKEN
export AWS_DEFAULT_REGION

if [[ -n "${AWS_ACCESS_KEY_ID:-}" && -z "$PROFILE_ARG" ]]; then
    PROFILE="${AWS_ACCESS_KEY_ID}"
    SRC_PROFILE="${AWS_ACCESS_KEY_ID}"
else
    #
    # Friendly error if AWS config file doesn't exist
    #

    if [[ ! -s $AWS_CONFIG_FILE ]]; then
        echo "[$(basename "$0")] Cannot find AWS CLI config file: $AWS_CONFIG_FILE" >&2
        exit 1
    fi

    #
    # Read AWS config file
    #

    if [[ "$PROFILE" == "default" ]]; then
        PROFILE_SECTION="default"
    else
        PROFILE_SECTION="profile $PROFILE"
    fi

    [[ -n "$ROLE_ARN" ]] || ROLE_ARN="$(configfield "$AWS_CONFIG_FILE" role_arn "$PROFILE_SECTION")"
    [[ -n "$SRC_PROFILE" ]] || SRC_PROFILE="$(configfield "$AWS_CONFIG_FILE" source_profile "$PROFILE_SECTION")"
    [[ -n "$REGION" ]] || REGION="$(configfield "$AWS_CONFIG_FILE" region "$PROFILE_SECTION")"
    MFA_SERIAL="$(configfield "$AWS_CONFIG_FILE" mfa_serial "$PROFILE_SECTION")"
    EXTERNAL_ID="$(configfield "$AWS_CONFIG_FILE" external_id "$PROFILE_SECTION")"
    [[ -n "$SRC_PROFILE" ]] || SRC_PROFILE="$PROFILE"

    if [[ "$SRC_PROFILE" == "default" ]]; then
        SRC_PROFILE_SECTION="default"
    else
        SRC_PROFILE_SECTION="profile $SRC_PROFILE"
    fi

    [[ -n "$MFA_SERIAL" ]] || \
        MFA_SERIAL="$(configfield "$AWS_CONFIG_FILE" mfa_serial "$SRC_PROFILE_SECTION")"
    [[ -n "$REGION" ]] || \
        REGION="$(configfield "$AWS_CONFIG_FILE" region "$SRC_PROFILE_SECTION")"

    if [[ "$(grep '^\['"$SRC_PROFILE_SECTION"'\]' "$AWS_CONFIG_FILE")" == "" && "$(grep '^\['"$SRC_PROFILE"'\]' "$HOME/.aws/credentials")" == "" ]]; then
        echo "[$(basename "$0")] Cannot find '$SRC_PROFILE' profile in AWS CLI configuration" >&2
        exit 1
    fi
fi

#
# Create temporary files used to avoid race conditions
#

mkdir -p "$CACHE_DIR"
CRED_TEMP="$(mktemp "$CACHE_DIR/temp_credentials.XXXXX")"
EXPIRE_TEMP="$(mktemp "$CACHE_DIR/temp_expire.XXXXX")"

#
# Create or use cached temporary session
#

MFA_CRED_PREFIX="$CACHE_DIR/${SRC_PROFILE}.${MFA_SERIAL//[:\/]/_}.session"
MFA_CRED_FILE="${MFA_CRED_PREFIX}_credentials.json"
MFA_EXPIRE_FILE="${MFA_CRED_PREFIX}_expire"
AWS_ENV_EXPIRE="$(cat "$MFA_EXPIRE_FILE" 2>/dev/null || true)"

# If session credentials expired or non-existant, prompt for MFA code (if
# required) and get a session token, and cache the session credentials.
if [[ ! -s "$MFA_CRED_FILE" || "$CURDATE" -ge "$AWS_ENV_EXPIRE" ]]; then
    echo "[$(basename "$0")] Getting session token for profile '$PROFILE'${PROFILE_SOURCE_CONFIG:+ from $PROFILE_SOURCE_CONFIG}" >&2
    if [[ -z "$ROLE_ARN" && -z "$MFA_SERIAL" ]]; then
        echo "[$(basename "$0")] WARNING: No role_arn or mfa_serial found for profile $PROFILE" >&2
    fi

    # Prompt for MFA code if 'mfa_serial' set in config file
    [[ -z "$MFA_SERIAL" ]] || \
        read -p "[$(basename "$0")] Enter MFA code for $MFA_SERIAL: " -r MFA_CODE </dev/tty

    # Record the refresh time in the temporary session expire file
    NEW_EXPIRE="$(( CURDATE + MFA_DURATION * MFA_REFRESH / 100 ))"
    echo "$NEW_EXPIRE" >"$EXPIRE_TEMP"

    # Get the session token and save credentials in temporary credentials file
    touch "$CRED_TEMP"
    chmod 0600 "$CRED_TEMP"
    if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]]; then
        aws sts get-session-token --duration-seconds="$MFA_DURATION" ${MFA_SERIAL:+"--serial-number=$MFA_SERIAL" "--token-code=$MFA_CODE"} --output json >"$CRED_TEMP"
    else
        aws --profile="$SRC_PROFILE" sts get-session-token --duration-seconds="$MFA_DURATION" ${MFA_SERIAL:+"--serial-number=$MFA_SERIAL" "--token-code=$MFA_CODE"} --output json >"$CRED_TEMP"
    fi

    # Move the temporary files to their cached locations
    mv "$CRED_TEMP" "$MFA_CRED_FILE"
    mv "$EXPIRE_TEMP" "$MFA_EXPIRE_FILE"
    AWS_ENV_EXPIRE="$NEW_EXPIRE"
fi

# Set the AWS_* credentials environment variables from values in the cached or
# just-created session credentials file
load_cred_vars "$MFA_CRED_FILE" "$MFA_EXPIRE_FILE"

#
# Assume the role or used cached credentials, if the 'role_arn' is set in the
# config file
#

if [[ -n "$ROLE_ARN" ]]; then
    ROLE_CRED_PREFIX="$CACHE_DIR/${PROFILE}.${ROLE_ARN//[:\/]/_}.role"
    ROLE_CRED_FILE="${ROLE_CRED_PREFIX}_credentials.json"
    ROLE_EXPIRE_FILE="${ROLE_CRED_PREFIX}_expire"
    AWS_ENV_EXPIRE="$(cat "$ROLE_EXPIRE_FILE" 2>/dev/null || true)"

    # If role credentials expired or non-existant, assume the role and cache the
    # credentials
    if [[ ! -s "$ROLE_CRED_FILE" || "$CURDATE" -ge "$AWS_ENV_EXPIRE" ]]; then
        echo "[$(basename "$0")] Assuming role $ROLE_ARN${ROLE_ARN_SOURCE_CONFIG:+ from $ROLE_ARN_SOURCE_CONFIG}" >&2

        # Record the refresh time in the assume-role expire temporary file
        NEW_EXPIRE="$(( CURDATE + ROLE_DURATION * ROLE_REFRESH / 100 ))"
        echo "$NEW_EXPIRE" >"$EXPIRE_TEMP"

        # Assume the role and save role credentials in temporary credential file
        touch "$CRED_TEMP"
        chmod 0600 "$CRED_TEMP"
        aws sts assume-role --duration-seconds="$ROLE_DURATION" --role-arn="$ROLE_ARN" --role-session-name="$(date +%Y%m%d-%H%M%S)" ${EXTERNAL_ID:+"--external-id=$EXTERNAL_ID"} --output json >"$CRED_TEMP"

        # Move the temporary files to their cached locations
        mv "$CRED_TEMP" "$ROLE_CRED_FILE"
        mv "$EXPIRE_TEMP" "$ROLE_EXPIRE_FILE"
        AWS_ENV_EXPIRE="$NEW_EXPIRE"
    fi

    # Set the AWS_* credentials environment variables from values in the cached or
    # just-created role credentials file
    load_cred_vars "$ROLE_CRED_FILE" "$ROLE_EXPIRE_FILE"
fi

#
# Set extra environment variables
#

[[ -z "$REGION" ]] || AWS_DEFAULT_REGION="$REGION"
AWS_ENV_CURRENT_PROFILE="$PROFILE"
export AWS_DEFAULT_REGION AWS_ENV_CURRENT_PROFILE

#
# Perform the desired action with the temporary session environment.
#

if [[ $# -gt 0 ]]; then
    # If there is a command specified, execute it.
    [[ -z "$REGION" ]] || AWS_DEFAULT_REGION="$REGION"
    export AWS_DEFAULT_REGION
    # The 'EXIT' trap isn't run when we 'exec', so explicitly clean up.
    cleanup
    exec "$@"
else
    # If no command, output a script to be 'eval'd.
    echo "export AWS_ACCESS_KEY_ID='$AWS_ACCESS_KEY_ID';"
    echo "export AWS_SECRET_ACCESS_KEY='$AWS_SECRET_ACCESS_KEY';"
    echo "export AWS_SESSION_TOKEN='$AWS_SESSION_TOKEN';"
    echo "export AWS_SECURITY_TOKEN='$AWS_SECURITY_TOKEN';"
    echo "export AWS_ENV_ORIG_ACCESS_KEY_ID='$AWS_ENV_ORIG_ACCESS_KEY_ID';"
    echo "export AWS_ENV_ORIG_SECRET_ACCESS_KEY='$AWS_ENV_ORIG_SECRET_ACCESS_KEY';"
    echo "export AWS_ENV_ORIG_SESSION_TOKEN='$AWS_ENV_ORIG_SESSION_TOKEN';"
    echo "export AWS_ENV_ORIG_SECURITY_TOKEN='$AWS_ENV_ORIG_SECURITY_TOKEN';"
    [[ -z "${AWS_DEFAULT_REGION:-}" ]] || echo "export AWS_DEFAULT_REGION='$AWS_DEFAULT_REGION';"
    echo "export AWS_ENV_CURRENT_PROFILE='$AWS_ENV_CURRENT_PROFILE';"
    setup_shell_prompt
    exit 0
fi
