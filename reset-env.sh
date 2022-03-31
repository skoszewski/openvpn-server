# NOTICE: This script MUST be executed using source mechanism:
#
# . reset-env.sh
#
# It cannot be executed in a separate process!
#

if [ -z "$1" ]
then
    echo "ERROR: Argument missing. Specify environment file name."
    return 1
fi

if [ ! -f "$1" ]
then
    echo "ERROR: \"$1\" does not exit."
    return 1
fi

unset $(cat "$1" | awk '/^export/ { print $2 }' | cut -d= -f1)

return 0