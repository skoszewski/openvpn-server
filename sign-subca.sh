#!/usr/bin/env bash

. functions.sh

usage() {
    echo "Usage: $0 -r <request_file>"
}

# Check, if the environment has been sourced. Stop, if not.
check_env -v || exit 1

while getopts "r:h" option
do
    case $option in
        r)
            REQ_FILE="$OPTARG"
            ;;
        h)
            usage
            exit 0
            ;;
    esac
done

# Sing the certificate
if openssl ca -config ca.conf -name "$CA_SECT" -in "$REQ_FILE" -extensions v3_end_ca -out "${REQ_FILE%.*}.crt"
then
    # Remove the request file.
    rm -f "$REQ_FILE"
fi
