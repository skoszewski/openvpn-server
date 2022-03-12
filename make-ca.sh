#!/usr/bin/env sh

# Source environment variables
. ./env.sh

# Create a directory for CA files
if [ -d $CA_ROOT ]
then
    rm -rf $CA_ROOT
fi

mkdir $CA_ROOT

# Create a new index, serial and subdirectories.
touch "$CA_ROOT/index.txt" "$CA_ROOT/index.txt.attr"
echo 01 > "$CA_ROOT/serial"
mkdir -m 755 "$CA_ROOT/newcerts" "$CA_ROOT/certs"
mkdir -m 750 "$CA_ROOT/private" "$CA_ROOT/configs"

# Write .rnd file (if supported)
openssl rand -writerand $CA_ROOT/.rnd 2>&1 1>&-

# Generate a self-signed CA root certificate
openssl req -x509 -days 3650 -out "$CA_CERT" -newkey rsa:2048 -nodes -keyout "$CA_KEY" -config ca.conf -extensions v3_ca

# Generate DH parameter file.
openssl dhparam -out "$CA_ROOT/dh.pem" 2048

# Generate static TLS key
openvpn --genkey --secret "$CA_ROOT/ta.key"

# Generate an empty CRL
openssl ca -gencrl -config ca.conf -out "$CA_CRL"

# Create a server certificate
REQ_FILE="$CA_ROOT/certs/server.req"
CERT_FILE="$CA_ROOT/certs/server.crt"
KEY_FILE="$CA_ROOT/private/server-key.txt"

SUBJ_CN="$SERVER_NAME"

# Create a certificate request
openssl req -out "$REQ_FILE" -newkey rsa:2048 -nodes -keyout "$KEY_FILE" -config ca.conf

# Sign the request
openssl ca -in "$REQ_FILE" -out "$CERT_FILE" -config ca.conf -extensions server_ext -batch

# Remove the request file
rm -f "$REQ_FILE"

# Check, if the OpenVPN has been installed, and copy files.
if [ -d "$OPENVPN_BASEDIR"  ]
then
    sudo cp $CA_CERT $OPENVPN_BASEDIR/ca.crt
    sudo cp $CERT_FILE $OPENVPN_BASEDIR/server.crt
    sudo cp $KEY_FILE $OPENVPN_BASEDIR/server.key
    sudo cp $CA_CRL $OPENVPN_BASEDIR/crl.pem
    sudo cp $CA_ROOT/ta.key $OPENVPN_BASEDIR
    
    if [ ! -f $OPENVPN_BASEDIR/dh.pem ]
    then
        sudo cp $CA_ROOT/dh.pem $OPENVPN_BASEDIR
    fi
fi
