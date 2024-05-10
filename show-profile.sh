#!/usr/bin/env bash

. functions.sh

usage() {
    echo "Usage: $(basename $0) { -n <client_name> | -b <base_name> } [ -d <dirname> ]"
    echo "       [ -f <filename> | -f - | -f ! ] [ -u <URL path> ]"
    echo "       [ -p tcp|udp ] [ -P <n> ]"
}

check_cert() {
    test -f "$CA_ROOT/certs/$BASE_NAME.crt" || exit_with_message "Certificate \"$BASE_NAME.crt\" does not exist."
}

# Check, if the environment has been sourced. Stop, if not.
check_env || exit 1

# Clear decision environment variables.
unset SAVE_PROFILE OUTPUT_DIR OUTPUT_FILE

while getopts "cn:b:hd:f:u:p:P:" option
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
            if [ "$OPTARG" = "-" ]
            then
                OUTPUT_DIR=$(echo $SERVER_PROFILE_DIRECTORY | sed 's/\/*$//')
            else
                OUTPUT_DIR=$(echo $OPTARG | sed 's/\/*$//')
            fi

            if [ ! -d "$OUTPUT_DIR" ]
            then
                echo "ERROR: Specified directory does not exist."
                exit 1
            fi
            ;;
        f)
            OUTPUT_FILE="$OPTARG"
            ;;
        u)
            if [ -n "$OPTARG" ]
            then
                URL_PATH=$(echo $OPTARG | sed 's|^/*||' | sed 's|/*$||')
                if [ -n "$URL_PATH" ]
                then
                    URL_PREFIX="${SERVER_FQDN}/$URL_PATH"
                else
                    URL_PREFIX=$SERVER_FQDN
                fi
            fi
            ;;
        # Override the server PORT and PROTOCOL setting in the profiles
        p)
            case "$OPTARG" in
                tcp)
                    SERVER_PROTOCOL="tcp"
                    ;;
                udp)
                    SERVER_PROTOCOL="udp"
                    ;;
                *)
                    echo "ERROR: The protocol must be tcp or udp."
                    exit 1
                    ;;
            esac
            ;;
        P)
            if echo "$OPTARG" | grep -E -q -v '^[[:digit:]]{1,5}$'
            then
                echo "ERROR: The argument to -P must be numeric."
                exit 1
            fi
            if [ $OPTARG -lt 1 ] || [ $OPTARG -gt 65534 ]
            then
                echo "ERROR: The argument to -P must be a number from 1-65534 range."
                exit 1
            fi
            SERVER_PORT="$OPTARG"
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
    test -z "$OUTPUT_FILE" && OUTPUT_FILE="$(openssl rand -hex 12).ovpn"
    test "$OUTPUT_FILE" = "!" && OUTPUT_FILE="$(cat "$CA_ROOT/certs/$BASE_NAME.crt" | sha256sum | head -c 24).ovpn"
    test "$OUTPUT_FILE" = "-" && OUTPUT_FILE="$BASE_NAME.ovpn"
    test -n "$URL_PREFIX" && DOWNLOAD_URL="$URL_PREFIX/$OUTPUT_FILE"
    test -n "$OUTPUT_DIR" && OUTPUT_FILE="$OUTPUT_DIR/$OUTPUT_FILE"
    
    echo "Saving the profile to \"$OUTPUT_FILE\"."
    test -n "$DOWNLOAD_URL" && echo "The profile will be available at: https://$DOWNLOAD_URL"
    show_profile > "$OUTPUT_FILE"
fi
