#!/bin/bash

. functions.sh

# Check, if the environment is setup
check_env -v || exit 1

# Publish the data
publish_crl_and_aia
