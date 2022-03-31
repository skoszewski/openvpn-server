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

    return 0 # TRUE
}

# Unset key variables
unset_env() {
    for v in CA_NAME CA_LONGNAME CA_ROOT CA_SECT SUBJ_O SUBJ_OU SUBJ_C SERVER_NAME SERVER_FQDN SERVER_WWW_PROTOCOL
    do
        unset "$v"
    done
}

# Check, if a certifcate exists and is valid (defaults to CA certificate)
check_cert() {
    # Check, if the needed variables are set.
    check_env || return 1

    # Check the certificate, or CA certificate
    if [ -z "$1" ]
    then
        CERT="$CA_ROOT/$CA_NAME.crt"
    else
        CERT="$1"
    fi

    echo Test if the file exists
    test -f "$CERT" || return 1

    echo Test if the file is a valid certifcate
    openssl x509 -in "$CERT" -noout 2>&-
}

check_key() {
    # Check, if the needed variables are set.
    check_env || return 1

    if [ -z "$1" ]
    then
        KEY="$CA_ROOT/private/$CA_NAME-key.txt"
    else
        KEY="$1"
    fi

    test -f "$KEY" || return 1

    openssl rsa -in "$KEY" -noout 2>&-
}
