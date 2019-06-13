#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
if [ -f $DIR/.env.sh ]; then
    source $DIR/.env.sh
fi
# sourcery
defaults write $DIR/Lunar/Info.plist Fabric -dict-add APIKey $FABRIC_API_KEY