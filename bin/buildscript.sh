#!/bin/bash

if [[ "$DISABLE_SENTRY" == 1 ]]; then
    exit 0
fi

if ! which sentry-cli >/dev/null; then
    npm i -g @sentry/cli
fi

export SENTRY_ORG=alin-panaitiu
export SENTRY_PROJECT=lunar
sentry-cli upload-dif --include-sources -o alin-panaitiu -p lunar --wait -- "$DWARF_DSYM_FOLDER_PATH" 2>&1 >> /tmp/lunar-buildscript.log &