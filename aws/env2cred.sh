#!/usr/bin/env bash
show_help() { cat <<'EOF'
env2cred: Saves aws credentials to file.
===============================================================

Copyright (c) 2020 FP Complete Corp.  
Author and maintainer: 

This tools aims to automate the writing of credentials to the ~/.aws/credentials
file from the credentials currently set in the environmental variables. This tools
comes from the necessity of having the credentials in that file for some applications
like terraform that read from it.

Installation
------------

### Requirements

Use this script after setting variables with aws-env.sh.

### Download and install

To install the latest version, download [the
script](https://raw.githubusercontent.com/fpco/devops-helpers/master/aws/env2cred.sh)
and put it somewhere on your PATH with execute bits, preferably named `env2cred`.
For example:

    wget -O env2cred https://raw.githubusercontent.com/fpco/devops-helpers/master/aws/env2cred.sh
    chmod a+x env2cred
    sudo mv env2cred /usr/local/bin/env2cred

Usage
-----

    env2cred

### Options

None.

EOF
}

# Removes the old section if it exists
remove_section() {
    sed -e '/^\['$1'\]$/,/^\[.*\]$/ { /^\['$1'\]$/b; /^\[.*\]$/b; d }' ~/.aws/credentials > ~/.aws/credentials.tmp
    sed -e '/^\['$1'\]$/d' ~/.aws/credentials.tmp > ~/.aws/credentials2.tmp
    echo >> ~/.aws/credentials2.tmp
    echo >> ~/.aws/credentials2.tmp
    cat -s ~/.aws/credentials2.tmp > ~/.aws/credentials
    rm ~/.aws/credentials.tmp
    rm ~/.aws/credentials2.tmp
}

# Write current variables to file
write_credentials() {
    echo '['$AWS_ENV_CURRENT_PROFILE']' >> ~/.aws/credentials
    echo 'aws_access_key_id='$AWS_ACCESS_KEY_ID >> ~/.aws/credentials
    echo 'aws_secret_access_key='$AWS_SECRET_ACCESS_KEY >> ~/.aws/credentials
    echo 'aws_session_token='$AWS_SESSION_TOKEN >> ~/.aws/credentials
}

remove_section $AWS_ENV_CURRENT_PROFILE
write_credentials