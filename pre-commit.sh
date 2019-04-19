#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

defaults write $DIR/Lunar/Info.plist Fabric -dict-add APIKey ''

git diff --diff-filter=d --staged --name-only | grep -e '\(.*\).swift$' | while read line; do
    echo "Formatting ${line}"
    swiftformat --wraparguments beforefirst --wrapcollections beforefirst "${line}";
    git add "$line";
done