#!/usr/bin/env sh

# Define functions
show_profile() {
    if [ -f "$CA_ROOT/profiles/$BASE_NAME.ovpn" ]
    then
        cat "$CA_ROOT/profiles/$BASE_NAME.ovpn"
    else
        echo "The profile for the specified client does not exist."
        exit 1
    fi
}

show_certificate() {
    if [ -f "$CA_ROOT/certs/$BASE_NAME.crt" ]
    then
        openssl x509 -noout -text -nameopt multiline -certopt no_pubkey,no_sigdump -in "$CA_ROOT/certs/$BASE_NAME.crt"
    else
        echo "The certificate for the specified client does not exist."
        exit 1
    fi

    
}

usage() {
    echo "Usage: $0 -n <client_name> [ -p ] [ -c ]"
}

# Source environment variables
. ./env.sh

while getopts "cpn:" option
do
    case $option in
        n)
            CLIENT_NAME="$OPTARG"
            ;;
        p)
            MODE="profile"
            ;;
        c)
            MODE="certificate"
    esac
done

if [ -z "$CLIENT_NAME" ]
then
    echo "ERROR: Client name not specified."
    usage
    exit 1
fi

# Verify that the client name does not contain illegal characters.
if echo $CLIENT_NAME | grep -q -v -P '^[a-zA-Z][a-zA-Z0-9 ()#_-]*[a-zA-Z0-9)]+$'
then
    echo "ERROR: The client name must start with a letter, use only letters, numbers,"
    echo "       dashes, underscores, a hash symbol (#) and parentheses."
    exit 1
fi

# Calculate basename.
BASE_NAME=$(echo "$CLIENT_NAME" | tr 'A-Z -' 'a-z__' | tr -d -c 'a-z0-9_')

case $MODE in
    profile)
        show_profile
        ;;
    certificate)
        show_certificate
        ;;
    *)
        show_profile
        ;;
esac
