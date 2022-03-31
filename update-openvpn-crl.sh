#!/usr/bin/env bash

. functions.sh

# Define functions
usage() {
    echo "Usage: $0 { -e | <ca_certificate_file> <crl_file> } [ -d <openvpn_server_config_dir> ] [ -H ]"
}

unset USE_HASH_AS_NAME

# Set the default OpenVPN Server config directory
OPENVPN_BASEDIR="/etc/openvpn/server"

if [ "$1" = "-e" ]
then
    check_env || exit 1

    CA_CERT_FILE="$CA_ROOT/$CA_NAME.crt"
    CA_CRL_FILE="$CA_ROOT/$CA_NAME.crl"

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

while getopts "d:Hh" option
do
    case $option in
        d)
            OPENVPN_BASEDIR="$OPTARG"
            ;;
        H)
            USE_HASH_AS_NAME=1
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
