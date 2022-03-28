#!/usr/bin/env bash

# Check environment
if test -z "$CA_ROOT"
then
    echo "ERROR: \$CA_ROOT not defined, please source the CA shell environment variables."
    exit 1
fi

openssl crl -noout -text -in "$CA_CRL"
