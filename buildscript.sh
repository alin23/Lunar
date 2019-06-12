#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
if [ -f $DIR/.env.sh ]; then
    source $DIR/.env.sh
fi
test "$FABRIC_BUILD_SECRET" && $DIR/Fabric.framework/run $FABRIC_API_KEY $FABRIC_BUILD_SECRET || true
