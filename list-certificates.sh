#!/usr/bin/env bash

. functions.sh

# Define functions
usage() {
    echo "Usage: $(basename $0) [ -f <client_filter> ] [ -c ]"
    echo ""
    echo "       NOTICE: The <client_filter> is an extended regular expression."
}

# An excellent description of console escape sequences may be found 
# in the following answer: https://stackoverflow.com/questions/4842424/list-of-ansi-color-escape-sequences
unset START_HIGHLIGHT RESET_CONSOLE VERBOSE EXPIRY_DATE

while getopts "chvf:" option
do
    case $option in
        c)
            START_HIGHLIGHT="\033[33;1m"
            RESET_CONSOLE="\033[0m"
            ;;
        f)
            CLIENT_FILTER="$OPTARG"
            ;;
        v)
            VERBOSE=1
            ;;
        h)
            usage
            exit 0
    esac
done

# Check, if the environment has been sourced. Stop, if not.
check_env -v || exit 1

# Parse CA's index.txt file. Filter valid certificates. Apply end-user specified regex and display.
cat $CA_ROOT/index.txt | grep -i '^v' | cut -d/ -f2- | while read line
    do
        echo $line |
            tr '/' '\n' |
            grep -i -E '^(cn|commonName|description)' |
            sed 's/^.*=//' |
            tr '\n' ':' |
            sed 's/:$/\n/' |
            while IFS=':' read BASE_NAME CLIENT_NAME
            do
                if [ ! -z "$CLIENT_FILTER" ]
                then
                    # The filter MUST NOT BE quoted.
                    if [[ ! "$BASE_NAME" =~ $CLIENT_FILTER ]] && [[ ! "$CLIENT_NAME" =~ $CLIENT_FILTER ]]
                    then
                        # Both the BASE_NAME and the CLIENT_NAME do not match to the filter,
                        # continue with the next client.
                        continue
                    fi
                fi

                if [ -z "$CLIENT_NAME" ]
                then
                    echo "[$BASE_NAME]"
                else
                    if [ -n "$VERBOSE" ]
                    then
                        # Find the expiry date
                        EXPIRY_DATE=$(date --date "$(openssl x509 -in $CA_ROOT/certs/${BASE_NAME//./_}.crt -dates -noout| grep '^notAfter' | cut -d= -f2)" "+%F %T")
                        NOW=$(date "+%F %T")

                        if [[ "$EXPIRY_DATE" > "$NOW" ]] || [[ "$EXPIRY_DATE" == "$NOW" ]]
                        then
                            EXPIRY_TEXT=" expires on $EXPIRY_DATE"
                        else
                            EXPIRY_TEXT=" expired!"
                        fi
                    fi
                    # Output the client name and base name (the server certificate will have dots in CN)
                    echo -e "$CLIENT_NAME [${START_HIGHLIGHT}${BASE_NAME//./_}${RESET_CONSOLE}]$EXPIRY_TEXT"
                fi
            done
    done
