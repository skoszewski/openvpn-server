#!/usr/bin/env bash

. functions.sh

usage() {
    echo "Usage: $(basename $0) -b <base_name>"
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
    # Certificate name not specified, show the default server certificate, if exists.
    echo "Showing the default server certificate:"
    BASE_NAME="${SERVER_FQDN//./_}"
fi

# Check, if the certificate is present.
test -f "$CA_ROOT/certs/$BASE_NAME.crt" || exit_with_message "Certificate \"$BASE_NAME.crt\" does not exist."

# Check, if the environment has been sourced. Stop, if not.
check_env || exit 1

show_certificate
