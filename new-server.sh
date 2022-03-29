#!/usr/bin/env bash

# Define functions
usage() {
    echo "Usage: $0 ..."
}

# Check environment
if test -z "$CA_ROOT"
then
    echo "ERROR: \$CA_ROOT not defined, please source the CA shell environment variables."
    exit 1
fi

# Calculate locations for CA key, certificate and CRL
CA_CERT="$CA_ROOT/$CA_NAME.crt"
CA_KEY="$CA_ROOT/private/$CA_NAME-key.txt"
CA_CRL="$CA_ROOT/$CA_NAME.crl"

while getopts "h" option
do
    case $option in
        h)
            usage
            exit 0
    esac
done


# Generate DH parameter file.
if [ -f "$OPENVPN_BASEDIR/dh.pem" ]
then
    read -p "The Diffie-Helman parameter file already exists, would you like to recreate it? " ans
    if echo $ans | grep -q '^[Yy]'
    then
        sudo openssl dhparam -out "$OPENVPN_BASEDIR/dh.pem" 2048
    fi
fi

# Generate static TLS key
openvpn --genkey --secret "$CA_ROOT/ta.key"

# Create a server certificate
REQ_FILE="$CA_ROOT/certs/server.req"
CERT_FILE="$CA_ROOT/certs/server.crt"
KEY_FILE="$CA_ROOT/private/server-key.txt"

SUBJECT_NAME="/CN=$SERVER_FQDN/O=$SUBJ_O/OU=$SUBJ_OU/C=$SUBJ_C/description=OpenVPN Server Certificate"

# Create a server certificate request
if openssl req -out "$REQ_FILE" -newkey rsa:2048 -nodes -keyout "$KEY_FILE" -config ca.conf -subj "$SUBJECT_NAME" -addext "subjectAltName=DNS:$SERVER_FQDN"
then
    # Sign the request (suppress output)
    if ! openssl ca -in "$REQ_FILE" -out "$CERT_FILE" -notext -config ca.conf -extensions server_ext -batch
    then
        echo "ERROR: Cannot sign the server certificate request."
        exit 1
    fi

    # Remove the request file
    rm -f "$REQ_FILE"
else
    echo "ERROR: Cannot create a server certificate request."
    exit 1
fi

# Check, if the OpenVPN has been installed, and copy files.
if [ -d "$OPENVPN_BASEDIR"  ]
then
    sudo cp $CA_ROOT/$CA_NAME.crt $OPENVPN_BASEDIR/ca.crt
    sudo cp $CERT_FILE $OPENVPN_BASEDIR/server.crt
    sudo cp $KEY_FILE $OPENVPN_BASEDIR/server.key
    sudo cp $CA_ROOT/$CA_NAME.crl $OPENVPN_BASEDIR/crl.pem
    sudo cp $CA_ROOT/ta.key $OPENVPN_BASEDIR
fi
