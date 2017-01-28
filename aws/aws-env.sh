#!/usr/bin/env bash
set -eu

show_help() {
    cat <<EOF
# aws-env: Wrapper for AWS temporary sessions using MFA and roles

This aims to be the "ultimate" AWS temporary session wrapper.  Highlights:

- Supports both MFA and assuming roles
- Caches credentials so you can share between shell sessions and don't get
  prompted for MFA codes unnecessarily
- Can be used either as a wrapper or \`eval\`'d
- Uses the same configuration files as the AWS CLI, with some extensions
- Supports directory context-sensitive configuration in \`aws-env.config\`
- Only non-standard dependency is the AWS CLI

To install the latest version, download from
https://raw.githubusercontent.com/fpco/devops-helpers/master/aws/aws-env.sh and
put it somewhere on your PATH with execute bits, preferably named \`aws-env\`.

Usage
-----

    $(basename "$0") \\
        [--help] \\
        [--profile NAME|-p NAME] \\
        [--role-arn ARN|-r ARN] \\
        [--mfa-duration-seconds DURATION] \\
        [--mfa-refresh-factor PERCENT] \\
        [--role-duration-seconds DURATION] \\
        [--role-refresh-factor PERCENT] \\
        [COMMAND [ARGS ...]]

Options
-------

\`--help\`: Display this help text and exit.

\`--profile NAME\`: Set the AWS CLI profile to use. If not specified, uses the
  value of AWS_DEFAULT_PROFILE or \`default\` if that is not set.

\`--role-arn ARN\`: ARN of role to assume.  Overrides the profile's value.

\`--mfa-duration-seconds DURATION\`: Set how long until the MFA session expires.
  This defaults to the maximum 129600 (36 hours).

\`--role-duration-seconds DURATION\`: Set how long until the role session expires.
  This defaults to the maximum 3600 (1 hour).

\`--role-refresh-factor PERCENT\`: Percentage of role token duration at which to
  refresh it. The default is to request a new token after 35% of the old token's
  duration has passed.

\`--mfa-refresh-factor PERCENT\`: Percentage of MFA token duration at which to
  refresh it. The default is to request a new token after 65% of the old token's
  duration has passed.

Arguments
---------

When given a COMMAND, executes the command in the context of the temporary
session. For example:

    aws-env -p admin terraform plan

Without a COMMAND, prints \`export\` commands to stdout suitable for evaluating by
the shell. For example:

    eval \$(aws-env -p admin)

Requirements
------------

You must have the AWS CLI installed. See
http://docs.aws.amazon.com/cli/latest/userguide/installing.html.

Configuration
-------------

aws-env gets configuration from two places:
- The AWS CLI configuration files, by default \`~/.aws/config\` and \`~/.aws/credentials\`.
- Its own \`aws-env.config\` and \`aws-env.config\`

### AWS CLI configuration file.

\`~/.aws/credentials\` must contain the initial credentials for connecting to AWS.
For example:

    [signin]
    aws_access_key_id=AKIA................
    aws_secret_access_key=BC/u....................................

\`~/.aws/config\` contains the MFA device ARN, role ARN and source
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

- Any profile, even those without a \`role_arn\`, may specify an \`mfa_serial\`.
  That means that if you don't use roles, aws-env can still prompt you for an
  MFA code and set temporary credentials (unlike the AWS CLI). For example (in
  \`~/.aws/config\`)

        [profile signin]
        mfa_serial=arn:aws:iam::987654321000:mfa/username

- aws-env will use the \`mfa_serial\` from the \`source_profile\`, so you don't
  need to repeat it in every role profile.

### aws-env configuration

The optional aws-env configuration files are read from the following locations,
in order, with values in that come earlier overriding those that come later.

- Current directory's \`.aws-env.config\`
- Current directory's \`aws-env.config\`
- Recursively in the parent directories' \`.aws-env.config\` and
  \`aws-env.config\`s, until (and not including) $HOME or the root.
- \`~/.aws-env.config\`

Here's an example:

    profile=signin
    role_arn=arn:aws:iam::123456789000:role/admin
    mfa_duration_seconds=43200
    role_duration_seconds=1800
    mfa_refresh_factor=50
    role_refresh_factor=10

The values correspond to the command-line options with the same names, so see
the [Options](#options) section for details. Command-line arguments override any
configuration in the aws-env config.

A typical way to use this is to put an \`aws-env.config\` in the root of your
project that specifies the role to assume when working on that project and name
of a profile that has the credentials and MFA device, and commit that to the
repository. As long as all users of the project have a consistent name for the
credentials profile, they can just prefix any AWS-using command with \`aws-env\`
and be sure it's run in the correct context. Users can add or override
configuration locally using \`.aws-env.config\` (note: has a dot at the
beginning).


Environment variables
---------------------

The following environment variables are read by aws-env:

\`AWS_DEFAULT_PROFILE\`: AWS CLI profile to use. Defaults to \`default\`.
\`default\` is used.

\`AWS_CONFIG_FILE\`: Location of the AWS CLI config file. Defaults to
\`~/.aws/config\`.

\`AWS_ENV_CACHE_DIR\`: Location of cached credentials. Defaults to
\`~/.aws-env/\`

The following environment variables are **set** by aws-env:

- \`AWS_ACCESS_KEY_ID\`
- \`AWS_SECRET_ACCESS_KEY\`
- \`AWS_SESSION_TOKEN\`
- \`AWS_SECURITY_TOKEN\`
- \`AWS_DEFAULT_REGION\`

File locations
--------------

By default, temporary credentials are stored in \`~/.aws-env/\`, AWS CLI
configuration is read from \`~/.aws/config\`, and aws-env configuration is read
from \`~/.aws-env.config\`.

EOF
}

#
# Constants
#

ENV_CONFIG_FILENAME=".aws-env.config"

#
# Functions
#

# Set AWS_* environment variables from a credentials JSON file output by 'aws sts'.
load_cred_vars() {
    AWS_ACCESS_KEY_ID="$(grep AccessKeyId "$1"|sed 's/.*: "\(.*\)".*/\1/')"
    AWS_SECRET_ACCESS_KEY="$(grep SecretAccessKey "$1"|sed 's/.*: "\(.*\)".*/\1/')"
    AWS_SESSION_TOKEN="$(grep SessionToken "$1"|sed 's/.*: "\(.*\)".*/\1/')"
    AWS_SECURITY_TOKEN="$AWS_SESSION_TOKEN"
}

# Set configuration variables from an aws-env config file if they are not already set.
load_env_config() {
    if [[ -s "$1" ]]; then
        if [[ -z "$PROFILE" ]]; then
            PROFILE="$(grep '^profile' "$1"|cut -d= -f2)"
            [[ -n "$PROFILE" ]] && PROFILE_SOURCE_CONFIG="$1"
        fi
        if [[ -z "$ROLE_ARN" ]]; then
            ROLE_ARN="$(grep '^role_arn' "$1"|cut -d= -f2)"
            [[ -n "$ROLE_ARN" ]] && ROLE_ARN_SOURCE_CONFIG="$1"
        fi
        [[ -z "$MFA_DURATION" ]] && \
            MFA_DURATION="$(grep '^mfa_duration_seconds' "$1"|cut -d= -f2)"
        [[ -z "$ROLE_DURATION" ]] && \
            ROLE_DURATION="$(grep '^role_duration_seconds' "$1"|cut -d= -f2)"
        [[ -z "$MFA_REFRESH" ]] && \
            MFA_REFRESH="$(grep '^mfa_refresh_factor' "$1"|cut -d= -f2)"
        [[ -z "$ROLE_REFRESH" ]] && \
            ROLE_REFRESH="$(grep '^role_refresh_factor' "$1"|cut -d= -f2)"
    fi
}

#
# Read aws-env.configs
#

ROLE_ARN=
ROLE_ARN_SOURCE_CONFIG=
PROFILE=
MFA_DURATION=
ROLE_DURATION=
MFA_REFRESH=
ROLE_REFRESH=
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

[[ -z "$MFA_DURATION" ]] && MFA_DURATION=129600
[[ -z "$ROLE_DURATION" ]] && ROLE_DURATION=3600
[[ -z "$MFA_REFRESH" ]] && MFA_REFRESH=65
[[ -z "$ROLE_REFRESH" ]] && ROLE_REFRESH=35
CACHE_DIR="${AWS_ENV_CACHE_DIR:-$HOME/.aws-env}"
[[ -z "$PROFILE" ]] && PROFILE="${AWS_DEFAULT_PROFILE:-default}"
AWS_CONFIG_FILE="${AWS_CONFIG_FILE:-$HOME/.aws/config}"

#
# Parse command-line
#

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile=*)
            PROFILE="${1#--profile=}"
            shift
            ;;
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        -p)
            PROFILE="$2"
            shift 2
            ;;
        --role-arn=*)
            ROLE_ARN="${1#--profile=}"
            shift
            ;;
        --role-arn)
            ROLE_ARN="$2"
            shift 2
            ;;
        -r)
            ROLE_ARN="$2"
            shift 2
            ;;
        --mfa-duration-seconds=*)
            MFA_DURATION="${1#--mfa-duration-seconds=}"
            shift
            ;;
        --mfa-duration-seconds)
            MFA_DURATION="$2"
            shift 2
            ;;
        --role-duration-seconds=*)
            ROLE_DURATION="${1#--role-duration-seconds=}"
            shift
            ;;
        --role-duration-seconds)
            ROLE_DURATION="$2"
            shift 2
            ;;
        --mfa-refresh-factor=*)
            MFA_REFRESH="${1#--mfa-refresh-factor=}"
            shift
            ;;
        --mfa-refresh-factor)
            MFA_REFRESH="$2"
            shift 2
            ;;
        --role-refresh-factor=*)
            ROLE_REFRESH="${1#--role-refresh-factor=}"
            shift
            ;;
        --role-refresh-factor)
            ROLE_REFRESH="$2"
            shift 2
            ;;
        -h)
            show_help
            exit 0
            ;;
        --help)
            show_help
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "[$(basename "$0")] Invalid argument: $1" >&2
            echo "Run '$(basename "$0") --help' for usage information."
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

#
# Friendly error if AWS config file doesn't exist
#

if [[ ! -s $AWS_CONFIG_FILE ]]; then
    echo "[$(basename "$0")] Cannot find AWS CLI config file: $AWS_CONFIG_FILE" >&2
    exit 1
fi

#
# Set name of section in AWS config file for the profile
#

if [[ "$PROFILE" == "default" ]]; then
    PROFILE_SECTION="default"
else
    PROFILE_SECTION="profile $PROFILE"
fi

#
# Read AWS config file
#

[[ -n "$ROLE_ARN" ]] || ROLE_ARN="$(sed -ne '/^\['"$PROFILE_SECTION"'\]/,/^\[/p' "$AWS_CONFIG_FILE"|grep '^role_arn'|cut -d= -f2)"
SRC_PROFILE="$(sed -ne '/\['"$PROFILE_SECTION"'\]/,/^\[/p' "$AWS_CONFIG_FILE"|grep '^source_profile'|cut -d= -f2)"
MFA_SERIAL="$(sed -ne '/^\['"$PROFILE_SECTION"'\]/,/^\[/p' "$AWS_CONFIG_FILE"|grep '^mfa_serial'|cut -d= -f2)"
EXTERNAL_ID="$(sed -ne '/^\['"$PROFILE_SECTION"'\]/,/^\[/p' "$AWS_CONFIG_FILE"|grep '^external_id'|cut -d= -f2)"
REGION="$(sed -ne '/^\['"$PROFILE_SECTION"'\]/,/^\[/p' "$AWS_CONFIG_FILE"|grep '^region'|cut -d= -f2)"
[[ -z "$SRC_PROFILE" ]] && SRC_PROFILE="$PROFILE"

if [[ "$SRC_PROFILE" == "default" ]]; then
    SRC_PROFILE_SECTION="default"
else
    SRC_PROFILE_SECTION="profile $SRC_PROFILE"
fi

[[ -z "$MFA_SERIAL" ]] && \
    MFA_SERIAL="$(sed -ne '/^\['"$SRC_PROFILE_SECTION"'\]/,/^\[/p' "$AWS_CONFIG_FILE"|grep '^mfa_serial'|cut -d= -f2)"
[[ -z "$REGION" ]] && \
    REGION="$(sed -ne '/^\['"$SRC_PROFILE_SECTION"'\]/,/^\[/p' "$AWS_CONFIG_FILE"|grep '^region'|cut -d= -f2)"

#
# Ensure existing variables don't interfere with operation, and set region
#

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN
unset AWS_SECURITY_TOKEN
[[ -n "$REGION" ]] && AWS_DEFAULT_REGION="$REGION"
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN AWS_DEFAULT_REGION

#
# Create temporary files used to avoid race conditions
#

mkdir -p "$CACHE_DIR"
CRED_TEMP="$(mktemp "$CACHE_DIR/temp_credentials.XXXXX")"
EXPIRE_TEMP="$(mktemp "$CACHE_DIR/temp_expire.XXXXX")"
trap "rm -f \"$CRED_TEMP\" \"$EXPIRE_TEMP\"" EXIT

#
# Create or use cached temporary session
#

MFA_CRED_PREFIX="$CACHE_DIR/${SRC_PROFILE}.${MFA_SERIAL//[:\/]/_}.session"
MFA_CRED_FILE="${MFA_CRED_PREFIX}_credentials.json"
MFA_EXPIRE_FILE="${MFA_CRED_PREFIX}_expire"

# If session credentials expired or non-existant, prompt for MFA code (if
# required) and get a session token, and cache the session credentials.
if [[ ! -s "$MFA_CRED_FILE" || "$(date +%s)" -ge "$(cat "$MFA_EXPIRE_FILE" 2>/dev/null)" ]]; then
    echo "[$(basename "$0")] Getting session token for profile '$PROFILE'${PROFILE_SOURCE_CONFIG:+ from $PROFILE_SOURCE_CONFIG}" >&2
    if [[ -z "$ROLE_ARN" && -z "$MFA_SERIAL" ]]; then
        echo "[$(basename "$0")] WARNING: No role_arn or mfa_serial found for profile $PROFILE" >&2
    fi

    # Prompt for MFA code if 'mfa_serial' set in config file
    [[ -n "$MFA_SERIAL" ]] && \
        read -p "[$(basename "$0")] Enter MFA code for $MFA_SERIAL: " -r MFA_CODE </dev/tty


    # Record the refresh time in the temporary session expire file
    echo "$(( $(date +%s) + MFA_DURATION * MFA_REFRESH / 100 ))" >"$EXPIRE_TEMP"

    # Get the session token and save credentials in temporary credentials file
    aws --profile="$SRC_PROFILE" sts get-session-token --duration-seconds="$MFA_DURATION" ${MFA_SERIAL:+"--serial-number=$MFA_SERIAL" "--token-code=$MFA_CODE"} >"$CRED_TEMP"

    # Move the temporary files to their cached locations
    mv "$CRED_TEMP" "$MFA_CRED_FILE"
    mv "$EXPIRE_TEMP" "$MFA_EXPIRE_FILE"
fi

# Set the AWS_* credentials environment variables from values in the cached or
# just-created session credentials file
load_cred_vars "$MFA_CRED_FILE"

#
# Assume the role or used cached credentials, if the 'role_arn' is set in the
# config file
#

if [[ -n "$ROLE_ARN" ]]; then
    ROLE_CRED_PREFIX="$CACHE_DIR/${PROFILE}.${ROLE_ARN//[:\/]/_}.role"
    ROLE_CRED_FILE="${ROLE_CRED_PREFIX}_credentials.json"
    ROLE_EXPIRE_FILE="${ROLE_CRED_PREFIX}_expire"

    # If role credentials expired or non-existant, assume the role and cache the
    # credentials
    if [[ ! -s "$ROLE_CRED_FILE" || "$(date +%s)" -ge "$(cat "$ROLE_EXPIRE_FILE" 2>/dev/null)" ]]; then
        echo "[$(basename "$0")] Assuming role $ROLE_ARN${ROLE_ARN_SOURCE_CONFIG:+ from $ROLE_ARN_SOURCE_CONFIG}" >&2

        # Record the refresh time in the assume-role expire temporary file
        echo "$(( $(date +%s) + ROLE_DURATION * ROLE_REFRESH / 100 ))" >"$EXPIRE_TEMP"

        # Assume the role and save role credentials in temporary credential file
        aws sts assume-role --duration-seconds="$ROLE_DURATION" --role-arn="$ROLE_ARN" --role-session-name="$(date +%Y%m%d-%H%M%S)" ${EXTERNAL_ID:+"--external-id=$EXTERNAL_ID"} >"$CRED_TEMP"

        # Move the temporary files to their cached locations
        mv "$CRED_TEMP" "$ROLE_CRED_FILE"
        mv "$EXPIRE_TEMP" "$ROLE_EXPIRE_FILE"
    fi

    # Set the AWS_* credentials environment variables from values in the cached or
    # just-created role credentials file
    load_cred_vars "$ROLE_CRED_FILE"
fi

#
# Perform the desired action with the temporary session environment.
#

if [[ $# -gt 0 ]]; then
    # If there is a command specified, execute it.
    exec "$@"
else
    # If no command, output a script to be 'eval'd.
    echo "export AWS_ACCESS_KEY_ID='$AWS_ACCESS_KEY_ID';"
    echo "export AWS_SECRET_ACCESS_KEY='$AWS_SECRET_ACCESS_KEY';"
    echo "export AWS_SESSION_TOKEN='$AWS_SESSION_TOKEN';"
    echo "export AWS_SECURITY_TOKEN='$AWS_SECURITY_TOKEN';"
fi
