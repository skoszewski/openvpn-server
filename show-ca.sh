#!/usr/bin/env bash

. functions.sh

# Check, if the environment has been sourced. Stop, if not.
check_env || exit 1

echo "Showing CA certificate from \"$CA_ROOT\":"
echo ""

openssl x509 -noout -text -nameopt multiline -certopt no_pubkey,no_sigdump -in "$CA_ROOT/$CA_NAME.crt"
