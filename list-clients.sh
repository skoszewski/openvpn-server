#!/usr/bin/env bash

# Define functions
usage() {
    echo "Usage: $0 [ -f <client_filter> ] "
    echo ""
    echo "       NOTICE: The <client_filter> is an extended regular expression."
}

# Source environment variables
. ./env.sh

while getopts "hf:" option
do
    case $option in
        f)
            CLIENT_FILTER="$OPTARG"
            ;;
        h)
            usage
            exit 0
    esac
done

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
                    if [[ ! "$BASE_NAME" =~ $CLIENT_FILTER ]] && [[ ! "$CLIENT_NAME" =~ $CLIENT_FILTER ]]
                    then
                        # Both the BASE_NAME and the CLIENT_NAME do not match to the filter,
                        # continue with the next client.
                        continue
                    fi
                fi

                echo "$CLIENT_NAME [$BASE_NAME]"
            done
    done
