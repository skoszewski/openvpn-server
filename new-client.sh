#!/usr/bin/env bash

# Define functions
usage() {
    echo "Usage: $0 -n <client_name> -b <base_name> [ -s <device_serial_number> ]"
}

# Source environment variables
. ./env.sh

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
SUBJECT_NAME="/CN=$BASE_NAME/O=$SUBJ_O/OU=$SUBJ_OU/C=$SUBJ_C/description=$CLIENT_NAME/serialNumber=$SERIAL_NUMBER"

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

# Compose and create or recreate the OpenVPN config file
cat > "$OVPN_FILE" <<EOF
# Client Name: "$CLIENT_NAME"
setenv PROFILE_NAME $BASE_NAME
client
dev tun
proto $SERVER_PROTOCOL
remote $SERVER_FQDN $SERVER_PORT
data-ciphers AES-256-GCM:AES-256-CBC
auth SHA256
float
resolv-retry infinite
nobind
persist-key
persist-tun
verb 3

<ca>
$(openssl x509 -in $CA_CERT)
</ca>

<cert>
$(openssl x509 -in $CERT_FILE)
</cert>

<key>
$(openssl rsa -in $KEY_FILE)
</key>

remote-cert-eku "TLS Web Server Authentication"

<tls-auth>
$(cat $CA_ROOT/ta.key)
</tls-auth>

key-direction 1
EOF

echo ""
echo "The certificate has been issued and an OpenVPN profile has been created."
echo "use the command:"
echo ""
echo "./show-client.sh -n \"$CLIENT_NAME\""
echo ""
echo "or"
echo ""
echo "./show-client.sh -b \"$BASE_NAME\""
echo ""
echo "to write the profile to the screen."
