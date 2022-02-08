#!/bin/bash

which git-format-staged >/dev/null 2>/dev/null || npm install --global git-format-staged
which swiftformat >/dev/null 2>/dev/null || brew install swiftformat

git-format-staged --formatter "swiftformat stdin --stdinpath '{}'" "*.swift"