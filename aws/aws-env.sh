#!/usr/bin/env bash
set -e

show_help() {
    cat <<EOF
# $(basename "$0"): Wrapper for AWS temporary sessions using MFA and roles

This aims to be the "ultimate" AWS temporary session wrapper.  Highlights:

- Supports both MFA and assuming roles
- Caches credentials so you can share between shell sessions and don't get
  prompted for MFA codes unnecessarily
- Can be used either as a wrapper or \`eval\`'d
- Uses the same configuration files as the AWS CLI
- Only non-standard dependency is the AWS CLI

Usage
-----

    $(basename "$0") \\
        [--profile PROFILE|-p PROFILE] \\
        [--mfa-duration-seconds DURATION] \\
        [--role-duration-seconds DURATION] \\
        [--mfa-refresh-factor PERCENT] \\
        [--role-refresh-factor PERCENT] \\
        [COMMAND [ARGS ...]]

Options
-------

\`--profile PROFILE\`: Set the AWS CLI profile to use. If not specified, uses the
  value of AWS_DEFAULT_PROFILE or \`default\` if that is not set.

\`--mfa-duration-seconds DURATION\`: Set how long until the MFA session expires.
  This defaults to the maximum 129600 (36 hours).

\`--role-duration-seconds DURATION\`: Set how long until the role session expires.
  This defaults to the maximum 3600 (1 hour).

\`--mfa-refresh-factor PERCENT\`: Percentage of MFA token duration at which to
  refresh it. The default is to request a new token after 65% of the old token's
  duration has passed.

\`--role-refresh-factor PERCENT\`: Percentage of role token duration at which to
  refresh it. The default is to request a new token after 35% of the old token's
  duration has passed.

Arguments
---------

When given a COMMAND, executes the command in the context of the temporary
session. For example:

    aws-env -p admin terraform plan

Without a COMMAND, prints \`export\` commands to stdout suitable for evaluating by
the shell. For example:

    eval \$($(basename "$0") -p admin)

Requirements
------------

You must have the AWS CLI installed. See
http://docs.aws.amazon.com/cli/latest/userguide/installing.html.

Configuration
-------------

$(basename "$0") uses the same configuration files as the AWS CLI, by default
\`~/.aws/config\` and \`~/.aws/credentials\`.

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

Environment variables
---------------------

\`AWS_DEFAULT_PROFILE\`: AWS profile to use. Defaults to \`default\`.
\`default\` is used.

\`AWS_CONFIG_FILE\`: Location of the AWS config file. Defaults to
\`~/.aws/config\`.

\`AWS_ENV_CACHE_DIR\`: Location of cached credentials. Default to
\`~/.aws/env/\`

\`AWS_ENV_MFA_DURATION\`: Default MFA token duration. Defaults to 129600 (36
hours).

\`AWS_ENV_ROLE_DURATION\`: Default role token duration. Defaults to 3600 (1
hour).

\`AWS_ENV_MFA_REFRESH\`: Default MFA token refresh factor. Defaults to 65.
hours).

\`AWS_ENV_ROLE_REFRESH\`: Default role token refresh factor. Defaults to 35.
hour).


File locations
--------------

By default, temporary credentials are stored in \`~/.aws/env/\`, and
configuration is read from \`~/.aws/config\`. These locations can be overridden
by environment variables.

EOF
}

#
# Defaults
#

MFA_DURATION=${AWS_ENV_MFA_DURATION:-129600}
ROLE_DURATION=${AWS_ENV_ROLE_DURATION:-3600}
MFA_REFRESH=${AWS_ENV_MFA_REFRESH:-65}
ROLE_REFRESH=${AWS_ENV_ROLE_REFRESH:-35}
CACHE_DIR="${AWS_ENV_CACHE_DIR:-$HOME/.aws/env}"
PROFILE="${AWS_DEFAULT_PROFILE:-default}"
CONFIG_FILE="${AWS_CONFIG_FILE:-$HOME/.aws/config}"

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
            echo "$(basename "$0"): Invalid argument: $1" >&2
            echo "Run '$(basename "$0") --help' for usage information"
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

#
# Friendly error if config file doesn't exist
#

if [[ ! -s $CONFIG_FILE ]]; then
    echo "$(basename "$0"): Cannot find AWS CLI config file: $CONFIG_FILE" >&2
    exit 1
fi

#
# Set name of section in AWS config file for the profile
#

if [[ "$PROFILE" == "default" ]]; then
    CONFIG_SECTION="default"
else
    CONFIG_SECTION="profile $PROFILE"
fi

#
# Read AWS config file
#

ROLE_ARN="$(sed -ne '/^\['"$CONFIG_SECTION"'\]/,/^\[/p' "$CONFIG_FILE"|grep '^role_arn'|cut -d= -f2)"
SRC_PROFILE="$(sed -ne '/\['"$CONFIG_SECTION"'\]/,/^\[/p' "$CONFIG_FILE"|grep '^source_profile'|cut -d= -f2)"
MFA_SERIAL="$(sed -ne '/^\['"$CONFIG_SECTION"'\]/,/^\[/p' "$CONFIG_FILE"|grep '^mfa_serial'|cut -d= -f2)"
EXTERNAL_ID="$(sed -ne '/^\['"$CONFIG_SECTION"'\]/,/^\[/p' "$CONFIG_FILE"|grep '^external_id'|cut -d= -f2)"
[[ -z "$SRC_PROFILE" ]] && SRC_PROFILE="$PROFILE"

#
# Ensure existing variables don't interfere with operation
#

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN
unset AWS_SECURITY_TOKEN
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN

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

CRED_FILE="$CACHE_DIR/${SRC_PROFILE}_session_credentials.json"
EXPIRE_FILE="$CACHE_DIR/${SRC_PROFILE}_session_expire"

# If session credentials expired or non-existant, prompt for MFA code (if
# required) and get a session token, and cache the session credentials.
if [[ ! -s "$CRED_FILE" || "$(date +%s)" -ge "$(cat "$EXPIRE_FILE" 2>/dev/null)" ]]; then
    if [[ -z "$ROLE_ARN" && -z "$MFA_SERIAL" ]]; then
        echo "$(basename "$0"): WARNING: No role_arn or mfa_serial found for $PROFILE in $CONFIG_FILE" >&2
    fi

    # Prompt for MFA code if 'mfa_serial' set in config file
    if [[ -n "$MFA_SERIAL" ]]; then
        echo -n "$(basename "$0"): Enter MFA code for $MFA_SERIAL: " >&2
        read -r MFA_CODE </dev/tty
    fi

    echo "$(basename "$0"): Getting session token${MFA_SERIAL:+ for $MFA_SERIAL}" >&2

    # Record the refresh time in the temporary session expire file
    echo "$(( $(date +%s) + MFA_DURATION * MFA_REFRESH / 100 ))" >"$EXPIRE_TEMP"

    # Get the session token and save credentials in temporary credentials file
    aws --profile="$SRC_PROFILE" sts get-session-token --duration-seconds="$MFA_DURATION" ${MFA_SERIAL:+"--serial-number=$MFA_SERIAL" "--token-code=$MFA_CODE"} >"$CRED_TEMP"

    # Move the temporary files to their cached locations
    mv "$CRED_TEMP" "$CRED_FILE"
    mv "$EXPIRE_TEMP" "$EXPIRE_FILE"
fi

# Set the AWS_* credentials environment variables from values in the cached or
# just-created session credentials file
AWS_ACCESS_KEY_ID="$(grep AccessKeyId "$CRED_FILE"|sed 's/.*: "\(.*\)".*/\1/')"
AWS_SECRET_ACCESS_KEY="$(grep SecretAccessKey "$CRED_FILE"|sed 's/.*: "\(.*\)".*/\1/')"
AWS_SESSION_TOKEN="$(grep SessionToken "$CRED_FILE"|sed 's/.*: "\(.*\)".*/\1/')"
AWS_SECURITY_TOKEN="$AWS_SESSION_TOKEN"

#
# Assume the role or used cached credentials, if the 'role_arn' is set in the
# config file
#

if [[ -n "$ROLE_ARN" ]]; then
    CRED_FILE="$CACHE_DIR/${PROFILE}_role_credentials.json"
    EXPIRE_FILE="$CACHE_DIR/${PROFILE}_role_expire"

    # If role credentials expired or non-existant, assume the role and cache the
    # credentials
    if [[ ! -s "$CRED_FILE" || "$(date +%s)" -ge "$(cat "$EXPIRE_FILE" 2>/dev/null)" ]]; then
        echo "$(basename "$0"): Assuming role $ROLE_ARN" >&2

        # Record the refresh time in the assume-role expire temporary file
        echo "$(( $(date +%s) + ROLE_DURATION * ROLE_REFRESH / 100 ))" >"$EXPIRE_TEMP"

        # Assume the role and save role credentials in temporary credential file
        aws sts assume-role --duration-seconds="$ROLE_DURATION" --role-arn="$ROLE_ARN" --role-session-name="$(date +%Y%m%d-%H%M%S)" ${EXTERNAL_ID:+"--external-id=$EXTERNAL_ID"} >"$CRED_TEMP"

        # Move the temporary files to their cached locations
        mv "$CRED_TEMP" "$CRED_FILE"
        mv "$EXPIRE_TEMP" "$EXPIRE_FILE"
    fi

    # Set the AWS_* credentials environment variables from values in the cached or
    # just-created role credentials file
    AWS_ACCESS_KEY_ID="$(grep AccessKeyId "$CRED_FILE"|sed 's/.*: "\(.*\)".*/\1/')"
    AWS_SECRET_ACCESS_KEY="$(grep SecretAccessKey "$CRED_FILE"|sed 's/.*: "\(.*\)".*/\1/')"
    AWS_SESSION_TOKEN="$(grep SessionToken "$CRED_FILE"|sed 's/.*: "\(.*\)".*/\1/')"
    AWS_SECURITY_TOKEN="$AWS_SESSION_TOKEN"
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
