#!/bin/sh
if [ -f ./.env.sh ]; then
    source ./.env.sh
fi
test "$FABRIC_BUILD_SECRET" && ./Fabric.framework/run $FABRIC_API_KEY $FABRIC_BUILD_SECRET || true
