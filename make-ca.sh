#!/usr/bin/env bash

# Check environment
if test -z "$CA_ROOT"
then
    echo "ERROR: \$CA_ROOT not defined, please source the CA shell environment variables."
    exit 1
fi

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

# Subject name with the current Year.Month
SUBJECT_NAME="/CN=OpenVPN CA $(date +%Y.%m)/O=$SUBJ_O/OU=$SUBJ_OU/C=$SUBJ_C/description=OpenVPN CA Root Certificate"

# Dummy BASE_NAME value
# export BASE_NAME="$CA_NAME"

# Generate a self-signed CA root certificate
if ! openssl req -x509 -days 3650 -out "$CA_CERT" -newkey rsa:2048 -nodes -keyout "$CA_KEY" -config ca.conf -extensions v3_ca -subj "$SUBJECT_NAME"
then
    echo "ERROR: Cannot create a self-signed CA certificate."
    exit 1
fi

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

SUBJECT_NAME="/CN=$SERVER_FQDN/O=$SUBJ_O/OU=$SUBJ_OU/C=$SUBJ_C/description=OpenVPN Server Root Certificate"

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
    # rm -f "$REQ_FILE"
else
    echo "ERROR: Cannot create a server certificate request."
    exit 1
fi

# Check, if the OpenVPN has been installed, and copy files.
if [ -d "$OPENVPN_BASEDIR"  ]
then
    sudo cp $CA_CERT $OPENVPN_BASEDIR/ca.crt
    sudo cp $CERT_FILE $OPENVPN_BASEDIR/server.crt
    sudo cp $KEY_FILE $OPENVPN_BASEDIR/server.key
    sudo cp $CA_CRL $OPENVPN_BASEDIR/crl.pem
    sudo cp $CA_ROOT/ta.key $OPENVPN_BASEDIR
fi
