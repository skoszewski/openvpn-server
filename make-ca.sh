#!/usr/bin/env bash

# Define functions
usage() {
    echo "Usage: $0 [ -s ] [ -c <certificate_file> ]"
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

unset SUB_CA

while getopts "sc:h" option
do
    case $option in
        c)
            if [ -f "$OPTARG" ]
            then
                # Check if the file is a valid certificate
                if ! openssl x509 -in "$OPTARG" -noout >/dev/null 2>&1
                then
                    echo "ERROR: The \"$OPTARG\" file is not a valid certificate."
                    exit 1
                fi
            else
                echo "ERROR: Specified file does not exist."
                exit 1
            fi

            CERT_FILE="$OPTARG"
            ;;
        s)
            SUB_CA=1
            ;;
        h)
            usage
            exit 0
    esac
done

# Create a directory for CA files
if [ -d "$CA_ROOT" ] && [ -f "$CA_ROOT/index.txt" ] && [ -f "$CA_KEY" ] && [ -f "$CA_CERT" ]
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
    if [ -f "$CA_KEY" ]
    then
        echo "ERROR: CA private key file exists. Cannot continue."
        exit 1
    fi

    # Generate a self-signed CA root certificate
    if ! openssl req -x509 -days 3650 -out "$CA_CERT" -newkey rsa:2048 -nodes -keyout "$CA_KEY" -config ca.conf -extensions v3_ca -subj "$SUBJECT_NAME"
    then
        echo "ERROR: Cannot create a self-signed CA certificate."
        exit 1
    fi
else
    if [ -z "$CERT_FILE" ]
    then
        if [ -f "$CA_KEY" ]
        then
            echo "ERROR: CA private key file exists. Cannot continue."
            exit 1
        fi

        # Generate a certificate request
        openssl req -new -out "$CA_ROOT/$CA_NAME.req" -newkey rsa:2048 -nodes -keyout "$CA_KEY" -config ca.conf -subj "$SUBJECT_NAME"

        echo "Certificate request created. Sign it with the Root CA certificate."
        # Print the request to the standard output.
        openssl req -in "$CA_ROOT/$CA_NAME.req"
        exit 0
    else
        if [ ! -f "$CA_KEY" ]
        then
            echo "ERROR: CA private key has been deleted. Cannot continue."
            exit 1
        fi

        # Copy signed certificate file.
        openssl x509 -in "$CERT_FILE" -out "$CA_CERT"
    fi
fi

# Create a new index, serial.
touch "$CA_ROOT/index.txt" "$CA_ROOT/index.txt.attr"
echo 01 > "$CA_ROOT/serial"

# Generate an empty CRL
openssl ca -gencrl -config ca.conf -out "$CA_CRL"
