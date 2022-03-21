#!/usr/bin/env bash

# Define functions
show_profile() {
    OVPN_FILE="$CA_ROOT/profiles/$BASE_NAME.ovpn"

    if [ -f $OVPN_FILE ]
    then
        cat "$OVPN_FILE"
    else
        echo "The profile for the specified client does not exist."
        exit 1
    fi
}

show_certificate() {
    CERT_FILE="$CA_ROOT/certs/$BASE_NAME.crt"
    
    if [ -f "$CERT_FILE" ]
    then
        openssl x509 -noout -text -nameopt multiline -certopt no_pubkey,no_sigdump -in "$CERT_FILE"
    else
        echo "The certificate for the specified client does not exist."
        exit 1
    fi
}

usage() {
    echo "Usage: $0 [ -n <client_name> | -b <base_name> ] [ -p ] [ -c ]"
}

# Source environment variables
. ./env.sh

while getopts "cn:b:h" option
do
    case $option in
        b)
            BASE_NAME="$OPTARG"
            ;;
        n)
            CLIENT_NAME="$OPTARG"
            ;;
        c)
            MODE="certificate"
            ;;
        h)
            usage
            exit 0
            ;;
    esac
done

if [ -z "$CLIENT_NAME" ] && [ -z "$BASE_NAME" ]
then
    echo "ERROR: Client not specified."
    usage
    exit 1
fi

if [ ! -z "$CLIENT_NAME" ]
then
    # Verify that the client name does not contain illegal characters.
    if echo $CLIENT_NAME | grep -q -v -P '^[a-zA-Z][a-zA-Z0-9 ()#_-]*[a-zA-Z0-9)]+$'
    then
        echo "ERROR: The client name must start with a letter, use only letters, numbers,"
        echo "       dashes, underscores, a hash symbol (#) and parentheses."
        exit 1
    fi
fi

# Calculate basename, if not defined.
test -z "$BASE_NAME" && BASE_NAME=$(echo "$CLIENT_NAME" | tr 'A-Z -' 'a-z__' | tr -d -c 'a-z0-9_')

case $MODE in
    certificate)
        show_certificate
        ;;
    *)
        show_profile
        ;;
esac
