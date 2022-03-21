#!/usr/bin/env bash

# Source environment variables
. ./env.sh

openssl crl -noout -text -in "$CA_CRL"
