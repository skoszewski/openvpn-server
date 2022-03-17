#!/usr/bin/env sh

# Source environment variables
. ./env.sh

CLIENT_NAME="$1"

# Define additional variables
CERT_FILE="$CA_ROOT/certs/$CLIENT_NAME.crt"
KEY_FILE="$CA_ROOT/private/$CLIENT_NAME-key.txt"
OVPN_FILE="$CA_ROOT/profiles/$CLIENT_NAME.ovpn"

if [ -f "$CERT_FILE" ] || [ -f "$KEY_FILE" ] || [ -f "$OVPN_FILE" ]
then
    # Revoke the certificate
    openssl ca -config ca.conf -revoke "$CERT_FILE" -crl_reason cessationOfOperation
    
    # Remove client certificate, key and OpenVPN configuration profile
    rm -f "$CERT_FILE" "$KEY_FILE" "$OVPN_FILE"

    # Generate a new CRL
    openssl ca -config ca.conf -gencrl -out "$CA_CRL"

    # Copy CRL file to the OpenVPN server configuration directory
    if [ -d $OPENVPN_BASEDIR ]
    then
        sudo cp $CA_CRL $OPENVPN_BASEDIR/crl.pem
    fi
fi
