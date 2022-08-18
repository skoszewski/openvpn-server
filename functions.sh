# Common CA management supporting functions

# Check environment
check_env() {
    for v in CA_NAME CA_LONGNAME CA_ROOT CA_SECT SUBJ_O SUBJ_OU SUBJ_C SERVER_NAME SERVER_FQDN SERVER_WWW_PROTOCOL
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

gen_crl() {
    # Generate, a new CRL
    check_env || return 1

    # Generate, a new CRL.
    openssl ca -config ca.conf -name "$CA_SECT" -gencrl -out "$CA_ROOT/$CA_NAME.crl"
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