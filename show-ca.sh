#!/usr/bin/env bash

# Check environment
if test -z "$CA_ROOT"
then
    echo "ERROR: \$CA_ROOT not defined, please source the CA shell environment variables."
    exit 1
fi

echo "Showing CA certificate from \"$CA_ROOT\":"
echo ""

openssl x509 -noout -text -nameopt multiline -certopt no_pubkey,no_sigdump -in "$CA_ROOT/$CA_NAME.crt"