#!/usr/bin/env bash

. functions.sh

usage() {
    echo "Usage: $0 { -u | -c }"
}

# Check, if the environment has been sourced. Stop, if not.
check_env -v || exit 1

while getopts "uc" option
do
    case $option in
        c)
            echo "Showing CA certificate from \"$CA_ROOT\":"
            echo ""

            openssl x509 -noout -text -nameopt multiline -certopt no_pubkey,no_sigdump -in "$CA_ROOT/$CA_NAME.crt"
            ;;
        u)
            URL="$SERVER_WWW_PROTOCOL://$SERVER_FQDN"
            echo -e "The server is available at \"$URL\"."
            echo -e "CA certificate can be downloaded from: \"$URL/$CA_NAME.crt\"."
            echo -e "Certificate revocation list is available from: \"$URL/$CA_NAME.crl\"."
            ;;
        h)
            usage
            exit 0
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done
