#!/usr/bin/env bash
set -xe
mkdir -p ~/.local/bin
if [ `uname` = "Darwin" ]; then
    curl --insecure -L https://www.stackage.org/stack/osx-x86_64 | tar xz --strip-components=1 --include '*/stack' -C ~/.local/bin
else
    curl -L https://www.stackage.org/stack/linux-x86_64 | tar xz --wildcards --strip-components=1 -C ~/.local/bin '*/stack'
fi
