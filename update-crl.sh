#!/usr/bin/env bash

. functions.sh

# Define functions
usage() {
    echo "Usage: $(basename $0) { -e | <ca_certificate_file> <crl_file> } ..."
    echo "       [ -d <openvpn_server_config_dir> ] [ -H ] [ -c ]"
}

unset USE_HASH_AS_NAME GEN_CRL

if [ "$1" = "-e" ]
then
    check_env || exit 1

    CA_CERT_FILE="$CA_ROOT/$CA_NAME.crt"
    CA_CRL_FILE="$CA_ROOT/$CA_NAME.crl"

    # Automatically set USE_HASH_AS_NAME=1, if a sub CA is detected, or a CA designed as Root.
    if is_sub_ca || [ "$CA_SECT" = "root_ca" ]
    then
        USE_HASH_AS_NAME=1
    fi

    shift
else
    if [ -z "$2" ] || [ -z "$1" ]
    then
        usage
        exit 1
    fi

    # Use script arguments as certificate and CRL file names
    CA_CERT_FILE="$1"
    CA_CRL_FILE="$2"

    shift
    shift
fi

while getopts "d:Hch" option
do
    case $option in
        d)
            OPENVPN_BASEDIR="$OPTARG"
            ;;
        H)
            USE_HASH_AS_NAME=1
            ;;
        c)
            GEN_CRL=1
            ;;
        h)
            usage
            exit 0
    esac
done

if ! check_cert $CA_CERT_FILE
then
    echo "ERROR: The CA certificate does not exist or is not valid."
    exit 1
fi

if [ ! -z "$GEN_CRL" ]
then
    if ! check_env
    then
        echo "ERROR: The CA envrionment hasn't been sourced. The CRL cannot be generated."
        exit 1
    fi

    # Generate, a new CRL.
    if ! gen_crl
    then
        echo "ERROR: Cannot generate a new CRL file."
        exit 1
    fi
fi

if ! check_crl $CA_CRL_FILE
then
    echo "ERROR: The CRL file does not exist or is not valid."
    exit 1
fi

if [ ! -d "$OPENVPN_BASEDIR" ]
then
    echo "ERROR: The OpenVPN server is not installed."
    exit 1
fi

echo "Updating files..."
if [ -n "$USE_HASH_AS_NAME" ]
then
    HASH="$(openssl x509 -in "$CA_CERT_FILE" -noout -subject_hash)"
    sudo cp -uv "$CA_CERT_FILE" "$OPENVPN_BASEDIR/$HASH.0"
    sudo cp -uv "$CA_CRL_FILE" "$OPENVPN_BASEDIR/$HASH.r0"
else
    sudo cp -uv "$CA_CERT_FILE" "$OPENVPN_BASEDIR/ca.crt"
    sudo cp -uv "$CA_CRL_FILE" "$OPENVPN_BASEDIR/crl.pem"
fi
