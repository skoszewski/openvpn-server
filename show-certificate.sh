#!/usr/bin/env bash

. functions.sh

usage() {
    echo "Usage: $0 -b <base_name>"
}

while getopts "b:h" option
do
    case $option in
        b)
            BASE_NAME="$OPTARG"
            ;;
        h)
            usage
            exit 0
            ;;
    esac
done

if [ -z "$BASE_NAME" ]
then
    echo "ERROR: Certificate base name not specified."
    usage
    exit 1
fi

# Check, if the certificate is present.
test -f "$CA_ROOT/certs/$BASE_NAME.crt" || exit_with_message "Certificate \"$BASE_NAME.crt\" does not exist."

# Check, if the environment has been sourced. Stop, if not.
check_env || exit 1

show_certificate
