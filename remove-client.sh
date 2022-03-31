#!/usr/bin/env bash

. functions.sh

# Define functions
usage() {
    echo "Usage: $0 -n { <client_name> | -b <base_name> }"
}

# Check, if the environment has been sourced. Stop, if not.
check_env -v || exit 1

while getopts "n:b:h" option
do
    case $option in
        b)
            BASE_NAME="$OPTARG"
            ;;
        n)
            CLIENT_NAME="$OPTARG"
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

# Define additional variables
CERT_FILE="$CA_ROOT/certs/$BASE_NAME.crt"

if [ -f "$CERT_FILE" ]
then
    echo -e "Found the client with the $(openssl x509 -nameopt multiline -certopt no_pubkey,no_sigdump -noout -text -in $CERT_FILE)\n"

    # Confirm the intent of removing the client
    read -p "Are you sure you want to remove the client ($BASE_NAME)? " ans

    if echo $ans | grep -q '^[yY]'
    then
        # Revoke the certificate
        openssl ca -config ca.conf -name "$CA_SECT" -revoke "$CERT_FILE" -crl_reason cessationOfOperation

        # Remove client certificate, key and OpenVPN configuration profile
        rm -f "$CERT_FILE"
        
        # Calculate CRL location
        CA_CRL="$CA_ROOT/$CA_NAME.crl"

        # Generate a new CRL
        openssl ca -config ca.conf -name "$CA_SECT" -gencrl -out "$CA_CRL"

        # Copy CRL file to the OpenVPN server configuration directory
        if [ -d $OPENVPN_BASEDIR ]
        then
            sudo cp $CA_CRL $OPENVPN_BASEDIR/crl.pem
        fi
    else
        exit 0
    fi
else
    echo "The profile for the specified client does not exist."
    exit 1
fi

KEY_FILE="$CA_ROOT/private/$BASE_NAME-key.txt"
OVPN_FILE="$CA_ROOT/profiles/$BASE_NAME.ovpn"

# Remove client private key and OpenVPN configuration profile
test -f $KEY_FILE && rm -f $KEY_FILE
test -f $OVPN_FILE && rm -f $OVPN_FILE
