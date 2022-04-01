#!/usr/bin/env bash

. functions.sh

# Define functions
usage() {
    echo "Usage: $0 [ -s ] [ -r ] [ -c <certificate_file> ]"
}

unset SUB_CA ROOT_CA CERT_FILE

while getopts "src:h" option
do
    case $option in
        s)
            # Mode: sub CA
            SUB_CA=1
            ;;

        r)
            # Mode: Root CA
            ROOT_CA=1
            ;;
        
        c)
            CERT_FILE="$OPTARG"
            ;;

        h)
            usage
            exit 0
    esac
done

# Check, if the environment has been sourced. Stop, if not.
check_env -v || exit 1

# Calculate locations for CA key, certificate and CRL
CA_CERT="$CA_ROOT/$CA_NAME.crt"
CA_KEY="$CA_ROOT/private/$CA_NAME-key.txt"

if [ -n "$CERT_FILE" ]
then
    # Check if the file is a valid certificate
    if ! check_cert "$CERT_FILE"
    then
        echo "ERROR: The \"$CERT_FILE\" file does not exit or is not a valid certificate."
        exit 1
    fi

    # Check, if the first phase of initialization has been completed (the key exists)
    if ! check_ca_key
    then
        echo "ERROR: The CA private key does not exist."
        exit 1
    fi

    # Check, if the CA certificate already exists.
    if check_ca_cert
    then
        echo "ERROR: The CA certificate already exists."
        exit 1
    fi

    # Mode: sub CA
    SUB_CA=1
fi

# Check, if ROOT_CA and SUB_CA have not been specified simultaneously.
if [ ! -z "$ROOT_CA" ] && [ ! -z "$SUB_CA" ]
then
    echo "ERROR: Root and Intermediate (Sub) CA mode cannot be specified at the same time."
    exit 1
fi

# Set default CA extensions
if [ -z "$ROOT_CA" ]
then
    CA_EXT="v3_end_ca"
else
    CA_EXT="v3_ca"
fi

# Create a directory for CA files
if [ -d "$CA_ROOT" ] && [ -f "$CA_ROOT/index.txt" ] && check_ca_key && check_ca_cert
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

# CA does not exist or not fully initialized, create directory structure
for d in "$CA_ROOT" "$CA_ROOT/newcerts" "$CA_ROOT/certs" "$CA_ROOT/private" "$CA_ROOT/profiles"
do
    if [ ! -d "$d" ]
    then
        mkdir "$d"
    fi
done

# Secure private and profiles directories
chmod 750 "$CA_ROOT/private" "$CA_ROOT/profiles"

# Write .rnd file (if supported)
openssl rand -writerand "$CA_ROOT/.rnd" 2>&1 1>&-

# Subject name with the current Year.Month
SUBJECT_NAME="/CN=$CA_LONGNAME $(date +%Y.%m)/O=$SUBJ_O/OU=$SUBJ_OU/C=$SUBJ_C/description=$CA_LONGNAME Certificate"

if [ -z "$SUB_CA" ]
then
    if check_key
    then
        echo "ERROR: CA private key file exists. Cannot continue."
        exit 1
    fi

    # Generate a self-signed CA root certificate
    if ! openssl req -x509 -days 3650 -out "$CA_CERT" -newkey rsa:2048 -nodes -keyout "$CA_KEY" -config ca.conf -extensions "$CA_EXT" -subj "$SUBJECT_NAME"
    then
        echo "ERROR: Cannot create a self-signed CA certificate."
        exit 1
    fi
else
    # Check, if the private key exists
    if check_ca_key
    then
        if ! check_ca_cert
        then
            if [ -n "$CERT_FILE" ]
            then
                # Copy signed certificate file.
                openssl x509 -in "$CERT_FILE" -out "$CA_CERT"
            else
                echo "ERROR: Certificate not found or not specified, cannot finish CA creation."
                exit 1
            fi
        fi
    else
        # Generate a certificate request
        openssl req -new -out "$CA_ROOT/$CA_NAME.req" -newkey rsa:2048 -nodes -keyout "$CA_KEY" -config ca.conf -extensions "$CA_EXT" -subj "$SUBJECT_NAME"

        echo "Certificate request created. Sign it with the Root CA certificate."
        # Print the request to the standard output.
        openssl req -in "$CA_ROOT/$CA_NAME.req"

        exit 0
    fi
fi

# Create a new index, serial.
touch "$CA_ROOT/index.txt" "$CA_ROOT/index.txt.attr"
echo 01 > "$CA_ROOT/serial"

# Generate an empty CRL
openssl ca -gencrl -config ca.conf -name "$CA_SECT" -out "$CA_ROOT/$CA_NAME.crl"
