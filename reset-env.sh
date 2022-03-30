#!/usr/bin/env bash

if [ -z "$1" ]
then
    echo "ERROR: Argument missing. Specify environment file name."
    exit 1
fi

if [ ! -f "$1" ]
then
    echo "ERROR: \"$1\" does not exit."
    exit 1
fi

unset $(cat "$1" | awk '/^export/ { print $2 }' | cut -d= -f1)
