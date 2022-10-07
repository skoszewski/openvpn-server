# Common CA management supporting functions

# Check environment
check_env() {
    for v in CA_NAME CA_LONGNAME CA_ROOT CA_SECT SUBJ_O SUBJ_C SERVER_NAME SERVER_FQDN SERVER_WWW_PROTOCOL
    do
        if test -z "${!v}"
        then
            echo "ERROR: Required environment variable is not defined ($v), please source the *.env file."
            return 1 # FALSE
        fi
    done

    if [ "$1" = "-v" ]
    then
        echo "Using CA in \"$CA_ROOT\"."
        echo ""
    fi
    
    return 0 # TRUE
}

# Check, if we are running as root
check_if_root() {
    if [ $(id -u) -ne "0" ]
    then
        echo "Run the script as root."
        exit 1
    fi
}

# Print an error message and exit
exit_with_message() {
    echo "ERROR: $1"
    exit 1
}

# Unset key variables
unset_env() {
    for v in CA_NAME CA_LONGNAME CA_ROOT CA_SECT SUBJ_O SUBJ_OU SUBJ_C SERVER_NAME SERVER_FQDN SERVER_WWW_PROTOCOL
    do
        unset "$v"
    done
}

# Check, if the certifcate exists and is valid (defaults to CA certificate)
check_cert() {
    local CERT="$1"

    test -n "$CERT" || return 1
    test -f "$CERT" || return 1
    openssl x509 -in "$CERT" -noout 2>&-
}

check_ca_cert() {
    check_env || return 1
    check_cert "$CA_ROOT/$CA_NAME.crt"
}

check_key() {
    local KEY="$1"
    
    test -n "$KEY" || return 1
    test -f "$KEY" || return 1
    openssl rsa -in "$KEY" -noout 2>&-
}

check_ca_key() {
    check_env || return 1
    check_key "$CA_ROOT/private/$CA_NAME-key.txt"
}

check_crl() {
    # Check, if the CRL exists and is valid
    local CRL="$1"

    test -n "$CRL" || return 1
    test -f "$CRL" || return 1
    openssl crl -in "$CRL" -noout 2>&-
}

check_ca_crl() {
    check_env || return 1
    check_crl "$CA_ROOT/$CA_NAME.crl"
}

publish_crl_and_aia() {
    check_env || return 1

    local DIR=${1:-$SERVER_CA_DIRECTORY}

    # Check, if webserver publishing directory has been defined ...
    test -n "$DIR" || return 0

    # ... and exists.
    test -d "$DIR" || return 1

    # Publish the CA root certificate and the CRL
    for file in "$CA_ROOT/$CA_NAME".{crt,crl}
    do
        # Do a copy as root.
        sudo cp -uv $file "$DIR/"
    done
}

gen_crl() {
    # Generate, a new CRL
    check_env || return 1

    # Generate, a new CRL.
    if openssl ca -config ca.conf -name "$CA_SECT" -gencrl -out "$CA_ROOT/$CA_NAME.crl"
    then
        # Copy CRL file to the OpenVPN server configuration directory
        if [ -d "$OPENVPN_BASEDIR" ]
        then
            sudo cp -v "$CA_ROOT/$CA_NAME.crl" "$OPENVPN_BASEDIR/crl.pem"
        fi
    else
        echo "ERROR: Cannot generate a new CRL."
        return 1
    fi
}

# Check, if the CA certificate is signed by another CA
is_sub_ca() {
    local CA_CERT_FILE

    # Read subject hash and issuer hash to an array
    if check_cert "$1"
    then
        CA_CERT_FILE="$1"
    else
        CA_CERT_FILE="$CA_ROOT/$CA_NAME.crt"
    fi
    echo "DEBUG: CA_CERT_FILE=$CA_CERT_FILE"
    # SUBJECT_HASH=$(openssl x509 -in "$CA_CERT_FILE" -noout -subject_hash)
    # ISSUER_HASH=$(openssl x509 -in "$CA_CERT_FILE" -noout -issuer_hash)
    # test $SUBJECT_HASH != $ISSUER_HASH
    HASHES=($(openssl x509 -in "$CA_CERT_FILE" -noout -subject_hash -issuer_hash))
    test ${HASHES[0]} != ${HASHES[1]}
}

revoke_cert() {
    check_env || return 1

    local CERT_FILE="$1"

    if check_cert "$CERT_FILE"
    then
        # Revoke the certificate
        openssl ca -config ca.conf -name "$CA_SECT" -revoke "$CERT_FILE" -crl_reason cessationOfOperation

        # Generate a new CRL
        openssl ca -config ca.conf -name "$CA_SECT" -gencrl -out "$CA_ROOT/$CA_NAME.crl"
    fi
}

# Show OpenVPN profile (output to STDOUT)
show_profile() {
    # Check, if the BASE_NAME variable is not empty.
    test -n "$BASE_NAME" || { echo "ERROR: \$BASE_NAME is not set."; return 1; }

    # Check, if the required files are present.
    test -f "$CA_ROOT/$CA_NAME.crt" || { echo "ERROR: Root CA certificate is missing."; return 1; }
    test -f "$CA_ROOT/certs/$BASE_NAME.crt" || { echo "ERROR: Certificate \"$BASE_NAME.crt\" is missing."; return 1; }
    test -f "$CA_ROOT/private/$BASE_NAME-key.txt" || { echo "ERROR: Private key \"$BASE_NAME-key.txt\" is missing."; return 1; }
    test -f "$CA_ROOT/ta.key" || { echo "ERROR: TLS key is missing."; return 1; }

    # Compose and create or recreate the OpenVPN config file
    cat <<EOF
# Client Name: "$CLIENT_NAME"
setenv PROFILE_NAME $BASE_NAME
client
dev tun
proto ${SERVER_PROTOCOL/tcp/tcp-server}
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
$(cat "$CA_ROOT/ta.key")
</tls-auth>

key-direction 1
EOF
}

# Show client certificate
show_certificate() {
    test -n "$BASE_NAME" || { echo "ERROR: \$BASE_NAME not defined."; return 1; }

    local CERT_FILE="$CA_ROOT/certs/$BASE_NAME.crt"
    
    if [ -f "$CERT_FILE" ]
    then
        openssl x509 -noout -text -nameopt multiline -certopt no_pubkey,no_sigdump -in "$CERT_FILE"
    else
        echo "The certificate for the specified client does not exist."
        return 1
    fi
}

# Build the subject name of the certificate
build_subject_name() {
    local CN="$1"
    # Optional description
    local DESC="$2"

    test -n "$CN" || { echo "ERROR: Common name not defined."; return 1; }

    SUBJECT_NAME="/CN=$CN/O=$SUBJ_O"

    if [ -n "$SUBJ_OU" ]
    then
        SUBJECT_NAME="$SUBJECT_NAME/OU=$SUBJ_OU"
    fi

    SUBJECT_NAME="$SUBJECT_NAME/C=$SUBJ_C"

    if [ -n "$DESC" ]
    then
        SUBJECT_NAME="$SUBJECT_NAME/description=$DESC"
    fi

    return 0
}
