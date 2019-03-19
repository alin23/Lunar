#!/bin/sh
if [ -f ./.env.sh ]; then
    source ./.env.sh
fi
sourcery
