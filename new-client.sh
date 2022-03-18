#!/usr/bin/env sh

# Define functions
usage() {
    echo "Usage: $0 -n <client_name> -b <base_name>"
}

# Source environment variables
. ./env.sh

while getopts "n:b:h" option
do
    case $option in
        b)
            BASE_NAME="$OPTARG"
            ;;
        n)
            CLIENT_NAME="$OPTARG"
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
test -z "$BASE_NAME" && BASE_NAME=$(echo "$CLIENT_NAME" | tr 'A-Z -' 'a-z__' | tr -d -c 'a-z0-9_')

# Define additional variables
REQ_FILE="$CA_ROOT/certs/$BASE_NAME.req"
CERT_FILE="$CA_ROOT/certs/$BASE_NAME.crt"
KEY_FILE="$CA_ROOT/private/$BASE_NAME-key.txt"
OVPN_FILE="$CA_ROOT/profiles/$BASE_NAME.ovpn"

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
