#!/usr/bin/env bash

. functions.sh

# Check, if the environment has been sourced. Stop, if not.
check_env -v || exit 1

openssl crl -noout -text -in "$CA_ROOT/$CA_NAME.crl"
