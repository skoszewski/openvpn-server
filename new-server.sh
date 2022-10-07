#!/usr/bin/env bash

# Include function definitions
. functions.sh

# Define functions
usage() {
    echo "Usage: $0 [ -s <server_fqdn> ] [ -r ] [ -c ] [ -n ] [ -d <certificate description> ]"
}

make_dh() {
    openssl dhparam -out "$CA_ROOT/dh.pem" 2048
    sudo cp -uv "$CA_ROOT/dh.pem" "$OPENVPN_BASEDIR/dh.pem"
}

make_ta_key() {
    openvpn --genkey --secret "$CA_ROOT/ta.key"
    sudo cp -uv "$CA_ROOT/ta.key" "$OPENVPN_BASEDIR/ta.key"
}

unset ROOT_CA COPY_ONLY SUBJ_DESC CERT_ONLY

while getopts "rs:chd:" option
do
    case $option in
        r)
            ROOT_CA=1
            ;;
        s)
            # Check, if the specified parameter is a valid FQDN
            if echo $OPTARG | grep -q -E '^([a-zA-Z0-9_-]+\.)+[a-zA-Z0-9_-]+$'
            then
                SERVER_FQDN="$OPTARG"
                SERVER_NAME="${SERVER_FQDN%%.*}"
            else
                echo "ERROR: The specified server name \"$OPTARG\" is not a valid FQDN."
                exit 1
            fi
            ;;
        c)
            COPY_ONLY=1
            ;;
        d)
            SUBJ_DESC="$OPTARG"
            ;;
        n)
            CERT_ONLY=1
            ;;
        h)
            usage
            exit 0
    esac
done

# Check, if the environment has been sourced. Stop, if not.
check_env -v || exit 1

# Use FQDN with replaced dots and dashes as a base name for files.
BASE_NAME="${SERVER_FQDN//./_}"

# Define server certificate files
REQ_FILE="$CA_ROOT/certs/$BASE_NAME.req"
CERT_FILE="$CA_ROOT/certs/$BASE_NAME.crt"
KEY_FILE="$CA_ROOT/private/$BASE_NAME-key.txt"

# Check, if the certificate already exists
if check_cert "$CERT_FILE"
then
    if [ -z "$COPY_ONLY" ]
    then
        echo "ERROR: The certifcate for $SERVER_FQDN already exists."
        exit 1
    fi

    echo "NOTICE: Using the existing certificate."
else
    # Compose a subject name
    # Add a description if explictly defined or the certificate will be issued
    # for the local OpenVPN service
    if [ -n "$SUBJ_DESC" ] || [ -z "$CERT_ONLY" ]
    then
        build_subject_name "$SERVER_FQDN" "${SUBJ_DESC:-OpenVPN Server Certificate}"
    else
        # or build a subject name without a description
        build_subject_name "$SERVER_FQDN"
    fi

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

    echo "NOTICE: Issued a certificate for $SERVER_FQDN."
    # Exit, if only X.509 certificate was requested
    test -n "$CERT_ONLY" && exit 0
fi

# Check, if the OpenVPN has been installed, and copy files.
if [ -d "$OPENVPN_BASEDIR"  ]
then
    echo "Installing or updating OpenVPN server files..."

    # Create a directory for client configuration files
    mkdir "$OPENVPN_BASEDIR/client-config"
    
    # Generate DH parameter file.
    if [ -f "$OPENVPN_BASEDIR/dh.pem" ]
    then
        read -p "The Diffie-Helman parameter file already exists, would you like to recreate it? " ans
        if echo $ans | grep -q '^[Yy]'
        then
            make_dh
        else
            # Copy already existing DH to CA_ROOT
            sudo cat "$OPENVPN_BASEDIR/dh.pem" > "$CA_ROOT/dh.pem"
        fi
    else
        make_dh
    fi

    # Generate static TLS key
    if [ -f "$OPENVPN_BASEDIR/ta.key" ]
    then
        read -p "The OpenVPN static TLS key already exists, would you like to recreate it? " ans
        if echo $ans | grep -q '^[Yy]'
        then
            make_ta_key
        else
            # Copy already existing TLS key to CA_ROOT
            sudo cat "$OPENVPN_BASEDIR/ta.key" > "$CA_ROOT/ta.key"
        fi
    else
        make_ta_key
    fi

    # Copy server certificate and key
    sudo cp -uv "$CERT_FILE" "$OPENVPN_BASEDIR/server.crt"
    sudo cp -uv "$KEY_FILE" "$OPENVPN_BASEDIR/server.key"

    # Copy CA certificate and CRL
    if [ -z "$ROOT_CA" ]
    then
        OPENVPN_CA_CERT="$OPENVPN_BASEDIR/ca.crt"
        OPENVPN_CRL="$OPENVPN_BASEDIR/crl.pem"
    else
        HASH="$(openssl x509 -in "$CA_ROOT/$CA_NAME.crt" -noout -subject_hash)"
        OPENVPN_CA_CERT="$OPENVPN_BASEDIR/$HASH.0"
        OPENVPN_CRL="$OPENVPN_BASEDIR/$HASH.r0"
    fi

    sudo cp -uv "$CA_ROOT/$CA_NAME.crt" "$OPENVPN_CA_CERT"
    sudo cp -uv "$CA_ROOT/$CA_NAME.crl" "$OPENVPN_CRL"
else
    echo "ERROR: OpenVPN configuration directory \"$OPENVPN_BASEDIR\" does not exit."
    exit 1
fi
