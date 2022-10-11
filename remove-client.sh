#!/usr/bin/env bash

. functions.sh

# Define functions
usage() {
    echo "Usage: $(basename $0) -n { <client_name> | -b <base_name> }"
}

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

if [ -n "$CLIENT_NAME" ]
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

# Check, if the environment has been sourced. Stop, if not.
check_env -v || exit 1

# Define additional variables
CERT_FILE="$CA_ROOT/certs/$BASE_NAME.crt"
KEY_FILE="$CA_ROOT/private/$BASE_NAME-key.txt"

if check_cert "$CERT_FILE"
then
    echo -e "Found the client with the $(openssl x509 -nameopt multiline -certopt no_pubkey,no_sigdump -noout -text -in $CERT_FILE)\n"

    # Confirm the intent of removing the client
    read -p "Are you sure you want to remove the client ($BASE_NAME)? " ans

    if echo $ans | grep -q -v '^[yY]'
    then
        echo -e "\nNOTICE: The certificate for the client ($BASE_NAME) will NOT BE revoked."
        exit 0
    fi

    # Revoke the certificate
    openssl ca -config ca.conf -name "$CA_SECT" -revoke "$CERT_FILE" -crl_reason cessationOfOperation
    
    # Generate a new CRL
    gen_crl || exit 1

    echo -e "\nNOTICE: Certificate has been revoked. Remember to publish the new CRL immediately !"

    # Remove client certificate, key and OpenVPN configuration profile
    rm -f "$CERT_FILE"

    # Remove the key if exists
    check_key $KEY_FILE && rm -f $KEY_FILE
else
    echo "The certificate for the specified client does not exist."
    exit 1
fi

