#!/usr/bin/env sh

# Source environment variables
. ./env.sh

CLIENT_NAME="$1"

# Define additional variables
REQ_FILE="$CA_ROOT/certs/$CLIENT_NAME.req"
CERT_FILE="$CA_ROOT/certs/$CLIENT_NAME.crt"
KEY_FILE="$CA_ROOT/private/$CLIENT_NAME-key.txt"
OVPN_FILE="$CA_ROOT/profiles/$CLIENT_NAME.ovpn"

# Check if the client already exists
if [ -f "$CERT_FILE" ] || [ -f "$KEY_FILE" ] || [ -f "$OVPN_FILE" ]
then
    echo "The client $CLIENT_NAME already exists. Remove the old client before continuing."
    exit 1
fi

# Define Subject Common Name
export SUBJ_CN="$CLIENT_NAME"

# Create a certificate request
openssl req -out "$REQ_FILE" -newkey rsa:2048 -nodes -keyout "$KEY_FILE" -config ca.conf

# Sign the request
openssl ca -in "$REQ_FILE" -out "$CERT_FILE" -config ca.conf -extensions client_ext -batch

# Remove the request file
rm -f "$REQ_FILE"

# Compose OpenVPN config file
cat >> "$OVPN_FILE" <<EOF
client
dev tun
proto $SERVER_PROTOCOL
remote $SERVER_NAME $SERVER_PORT
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
