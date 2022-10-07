#!/usr/bin/env bash

. functions.sh

# Define functions
usage() {
    echo "Usage: $0 -n <client_name> -b [ <base_name> ] [ -s <device_serial_number> ]"
}

while getopts "n:b:s:h" option
do
    case $option in
        b)
            BASE_NAME="$OPTARG"
            ;;
        n)
            CLIENT_NAME="$OPTARG"
            ;;
        s)
            SERIAL_NUMBER="$OPTARG"
            ;;
        h)
            usage
            exit 0
    esac
done

if [ -z "$CLIENT_NAME" ]
then
    echo "ERROR: Client name not specified."
    usage
    exit 1
fi

# Verify that the client name does not contain illegal characters.
if echo $CLIENT_NAME | grep -q -v -P '^[a-zA-Z][a-zA-Z0-9 ()#_-]*[a-zA-Z0-9)]+$'
then
    echo "ERROR: The client name must start with a letter, use only letters, numbers,"
    echo "       dashes, underscores, a hash symbol (#) and parentheses."
    exit 1
fi

# Calculate basename, if not defined.
if [ -z "$BASE_NAME" ]
then
    BASE_NAME=$(echo "$CLIENT_NAME" | tr 'A-Z -' 'a-z__' | tr -d -c 'a-z0-9_')
else
    # Check the basename for correct format
    if echo $BASE_NAME | grep -q -v -P '^[a-z][a-z0-9_]+$'
    then
        echo "ERROR: The base name must start with a letter and use only letters,"
        echo "       numbers and underscores."
        exit 1
    fi
fi

# Check, if the environment has been sourced. Stop, if not.
check_env -v || exit 1

# Check, the CA certificate
if ! check_ca_cert
then
    echo "ERROR: The CA certifcate is missing or is invalid."
    exit 1
fi

# Check, if the TLS key has been created.
if [ ! -f "$CA_ROOT/ta.key" ]
then
    echo "ERROR: The TLS key is missing."
    exit 1
fi

# Define additional variables
REQ_FILE="$CA_ROOT/certs/$BASE_NAME.req"
CERT_FILE="$CA_ROOT/certs/$BASE_NAME.crt"
KEY_FILE="$CA_ROOT/private/$BASE_NAME-key.txt"
OVPN_FILE="$CA_ROOT/profiles/$BASE_NAME.ovpn"

# Check if the client already exists
if [ -f "$CERT_FILE" ]
then
    echo "The client $CLIENT_NAME already exists. Remove the old client before continuing."
    exit 1
fi

# Define Subject Common Name
build_subject_name "$BASE_NAME" "$CLIENT_NAME"

if [ -n "$SERIAL_NUMBER" ]
then
    SUBJECT_NAME="$SUBJECT_NAME/serialNumber=$SERIAL_NUMBER"
fi

# Create a certificate request
if ! openssl req -verbose -out "$REQ_FILE" -newkey rsa:2048 -nodes -keyout "$KEY_FILE" -config ca.conf -subj "$SUBJECT_NAME" -addext "subjectAltName=DNS:$BASE_NAME"
then
    echo "ERROR: Cannot create a certificate request."
    exit 1
fi

# Sign the request
if ! openssl ca -in "$REQ_FILE" -out "$CERT_FILE" -extensions client_ext -config ca.conf -batch
then
    echo "ERROR: Cannot sign the certificate request."
    exit 1
fi

# Remove the request file
rm -f "$REQ_FILE"

echo -e "\nThe certificate has been issued."
echo -e "You can print an OpenVPN profile using following the command:\n"
echo -e "./show-profile.sh -n \"$CLIENT_NAME\"\n"
echo -e "or\n"
echo -e "./show-profile.sh -b \"$BASE_NAME\"\n"
