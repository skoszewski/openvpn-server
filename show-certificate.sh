#!/usr/bin/env sh

# Source environment variables
. ./env.sh

CLIENT_NAME="$1"

# Define additional variables
CERT_FILE="$CA_ROOT/certs/$CLIENT_NAME.crt"

if [ -f "$CERT_FILE" ]
then
    openssl x509 -noout -text -nameopt multiline -certopt no_pubkey,no_sigdump -in "$CERT_FILE"
else
    echo "The certificate for the specified client does not exist."
    exit 1
fi
