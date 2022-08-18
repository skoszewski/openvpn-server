#!/usr/bin/env bash

. functions.sh

usage() {
    echo "Usage: $0 { -n <client_name> | -b <base_name> } [ -d <dirname> ] [ -f <filename> | -f - | -f + ]"
}

check_cert() {
    test -f "$CA_ROOT/certs/$BASE_NAME.crt" || exit_with_message "Certificate \"$BASE_NAME.crt\" does not exist."
}

# Check, if the environment has been sourced. Stop, if not.
check_env || exit 1

# Clear decision environment variables.
unset SAVE_PROFILE OUTPUT_DIR OUTPUT_FILE

while getopts "cn:b:hd:f:" option
do
    case $option in
        b)
            BASE_NAME="$OPTARG"
            ;;
        n)
            CLIENT_NAME="$OPTARG"
            ;;
        d)
            SAVE_PROFILE=1
            OUTPUT_DIR="$(echo $OPTARG | sed 's/\/*$//')"
            if [ ! -d "$OUTPUT_DIR" ]
            then
                echo "ERROR: Specified directory does not exist."
                exit 1
            fi
            ;;
        f)
            OUTPUT_FILE="$OPTARG"
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
then # Client name is not specified, BASE_NAME is defined.
    # Check, if the certificate is present.
    check_cert

    # Look for the client name in the certificate
    CLIENT_NAME="$(openssl x509 -noout -subject -in "$CA_ROOT/certs/$BASE_NAME.crt" -nameopt multiline | grep -E '^[[:space:]]*description' | sed 's/^.*= *//')"
else # Client name is specified, BASE_NAME must be calculated.
    # Verify that the client name does not contain illegal characters.
    if echo $CLIENT_NAME | grep -q -v -P '^[a-zA-Z][a-zA-Z0-9 ()#_-]*[a-zA-Z0-9)]+$'
    then
        echo "ERROR: The client name must start with a letter, use only letters, numbers,"
        echo "       dashes, underscores, a hash symbol (#) and parentheses."
        exit 1
    fi

    BASE_NAME=$(echo "$CLIENT_NAME" | tr 'A-Z -' 'a-z__' | tr -d -c 'a-z0-9_')
    # Check, if the certificate is present.
    check_cert
fi

# Check, if the profile should be printed to the console or saved to a file.
if [ -z "$SAVE_PROFILE" ]
then
    show_profile
else
    test -z "$OUTPUT_FILE" && OUTPUT_FILE="$BASE_NAME.ovpn"
    test "$OUTPUT_FILE" = "!" && OUTPUT_FILE="$(openssl rand -hex 12).ovpn"
    test "$OUTPUT_FILE" = "-" && OUTPUT_FILE="$(cat "$CA_ROOT/certs/$BASE_NAME.crt" | sha256sum | head -c 24).ovpn"
    test -n "$OUTPUT_DIR" && OUTPUT_FILE="$OUTPUT_DIR/$OUTPUT_FILE"
    
    echo "Saving the profile to \"$OUTPUT_FILE\"."
    show_profile > "$OUTPUT_FILE"
fi
