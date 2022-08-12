#!/usr/bin/env bash

. functions.sh

# Define functions
show_profile() {
    # Compose and create or recreate the OpenVPN config file
    cat <<EOF
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
remote-cert-eku "TLS Web Server Authentication"

<ca>
$(openssl x509 -in "$CA_ROOT/$CA_NAME.crt")
</ca>

<cert>
$(openssl x509 -in "$CA_ROOT/certs/$BASE_NAME.crt")
</cert>

<key>
$(openssl rsa -in "$CA_ROOT/private/$BASE_NAME-key.txt" 2>&-)
</key>

<tls-auth>
$(cat $CA_ROOT/ta.key)
</tls-auth>

key-direction 1
EOF
}

show_certificate() {
    local CERT_FILE="$CA_ROOT/certs/$BASE_NAME.crt"
    
    if [ -f "$CERT_FILE" ]
    then
        openssl x509 -noout -text -nameopt multiline -certopt no_pubkey,no_sigdump -in "$CERT_FILE"
    else
        echo "The certificate for the specified client does not exist."
        exit 1
    fi
}

usage() {
    echo "Usage: $0 { -n <client_name> | -b <base_name> } [ -c ]"
}

while getopts "cn:b:h" option
do
    case $option in
        b)
            BASE_NAME="$OPTARG"
            ;;
        n)
            CLIENT_NAME="$OPTARG"
            ;;
        c)
            MODE="certificate"
            ;;
        h)
            usage
            exit 0
            ;;
    esac
done

if [ -z "$CLIENT_NAME" ] && [ -z "$BASE_NAME" ]
then
    echo "ERROR: Client not specified."
    usage
    exit 1
fi

if [ -z "$CLIENT_NAME" ]
then
    # Look for the client name in the certificate
    CLIENT_NAME=$(openssl x509 -noout -subject -in "$CA_ROOT/certs/$BASE_NAME.crt" -nameopt multiline | awk '/^[[:space:]]*description/ { print $3 }')
else
    # Verify that the client name does not contain illegal characters.
    if echo $CLIENT_NAME | grep -q -v -P '^[a-zA-Z][a-zA-Z0-9 ()#_-]*[a-zA-Z0-9)]+$'
    then
        echo "ERROR: The client name must start with a letter, use only letters, numbers,"
        echo "       dashes, underscores, a hash symbol (#) and parentheses."
        exit 1
    fi
fi

# Calculate basename, if not defined.
test -z "$BASE_NAME" && BASE_NAME=$(echo "$CLIENT_NAME" | tr 'A-Z -' 'a-z__' | tr -d -c 'a-z0-9_')

# Check, if the environment has been sourced. Stop, if not.
check_env || exit 1

case $MODE in
    certificate)
        show_certificate
        ;;
    *)
        show_profile
        ;;
esac
