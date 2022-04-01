#!/usr/bin/env bash

# Include function definitions
. functions.sh

# Define functions
usage() {
    echo "Usage: $0 [ -s <server_fqdn> ]"
}

while getopts "rs:ch" option
do
    case $option in
        s)
            # Check, if the specified parameter is a valid FQDN
            if echo $OPTARG | grep -q -E '^([a-zA-Z0-9_-]+\.)+[a-zA-Z0-9_-]+$'
            then
                SERVER_FQDN="$OPTARG"
                SERVER_NAME="${SERVER_FQDN%%.*}"
            else
                echo "ERROR: The specified server name \"$OPTARG\" is not a valid FQDN."
                exit 1
            fi
            ;;
        h)
            usage
            exit 0
    esac
done

# Check, if the environment has been sourced. Stop, if not.
check_env -v || exit 1

# Use FQDN with replaced dots and dashes as a base name for files.
BASE_NAME="${SERVER_FQDN//./_}"

# Define server certificate files
CERT_FILE="$CA_ROOT/certs/$BASE_NAME.crt"
KEY_FILE="$CA_ROOT/private/$BASE_NAME-key.txt"

# Check, if the certificate exists
if check_cert "$CERT_FILE"
then
    echo -e "Found the server $(openssl x509 -nameopt multiline -certopt no_pubkey,no_sigdump -noout -text -in $CERT_FILE)\n"

    # Confirm the intent of removing the client
    read -p "Are you sure you want to revoke the server's ($BASE_NAME) certificate ? " ans

    if echo $ans | grep -q -v '^[yY]'
    then
        echo -e "\nNOTICE: The certificate for the \"$SERVER_FQDN\" will NOT BE revoked."
        exit 0
    fi

    # Revoke the certificate and generate a new CRL
    openssl ca -config ca.conf -name "$CA_SECT" -revoke "$CERT_FILE" -crl_reason cessationOfOperation
    gen_crl
    echo -e "\nNOTICE: Certificate revoked. Remember to publish the new CRL immediately !"

    # Remove client certificate, key and OpenVPN configuration profile
    rm -f "$CERT_FILE"

    # Remove the key if exists
    if check_key $KEY_FILE
    then
        rm -f "$KEY_FILE"
    fi
fi
