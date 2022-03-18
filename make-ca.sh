#!/usr/bin/env sh

# Source environment variables
. ./env.sh

# Create a directory for CA files
if [ -d $CA_ROOT ]
then
    read -p "The CA already exists, do you want to recreate it? " ans
    
    if echo $ans | grep -q '^[yY]'
    then 
        echo "Removing the CA database at \"$CA_ROOT\"."
        rm -rf $CA_ROOT
    else
        exit 0
    fi
fi

mkdir $CA_ROOT

# Create a new index, serial and subdirectories.
touch "$CA_ROOT/index.txt" "$CA_ROOT/index.txt.attr"
echo 01 > "$CA_ROOT/serial"
mkdir -m 755 "$CA_ROOT/newcerts" "$CA_ROOT/certs"
mkdir -m 750 "$CA_ROOT/private" "$CA_ROOT/profiles"

# Write .rnd file (if supported)
openssl rand -writerand $CA_ROOT/.rnd 2>&1 1>&-

# Generate a self-signed CA root certificate
openssl req -x509 -days 3650 -out "$CA_CERT" -newkey rsa:2048 -nodes -keyout "$CA_KEY" -config ca.conf -extensions v3_ca

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

# Generate an empty CRL
openssl ca -gencrl -config ca.conf -out "$CA_CRL"

# Create a server certificate
REQ_FILE="$CA_ROOT/certs/server.req"
CERT_FILE="$CA_ROOT/certs/server.crt"
KEY_FILE="$CA_ROOT/private/server-key.txt"

SUBJ_CN="$SERVER_FQDN"

# Create a certificate request
openssl req -out "$REQ_FILE" -newkey rsa:2048 -nodes -keyout "$KEY_FILE" -config ca.conf

# Sign the request (suppress output)
openssl ca -in "$REQ_FILE" -out "$CERT_FILE" -notext -config ca.conf -extensions server_ext -batch

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
fi
