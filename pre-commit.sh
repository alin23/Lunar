#!/bin/bash
git diff --diff-filter=d --staged --name-only | grep -e '\(.*\).swift$' | while read line; do
    echo "Formatting ${line}"
    swiftformat --wraparguments beforefirst --wrapcollections beforefirst "${line}";
    git add "$line";
done