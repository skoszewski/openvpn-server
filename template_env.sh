# Basic variables 
export CA_NAME="openvpn-ca"
export CA_LONGNAME="OpenVPN CA"

# Customize the company information below.
export SUBJ_O="Example Company Inc."
export SUBJ_OU="Shared IT"
export SUBJ_C="PL"

# CRL and AIA server information
export SERVER_NAME="openvpn-poc"
export SERVER_DOMAIN="example.com"
export SERVER_WWW_PROTOCOL="http"

# AIA, CRL and published profiles location
export SERVER_CA_DIRECTORY="/var/www/html"
export SERVER_PROFILE_DIRECTORY="/var/www/html/profiles"

# OpenVPN server information
export OPENVPN_BASEDIR="/etc/openvpn/server"
export SERVER_PROTOCOL="udp"
export SERVER_PORT="1194"

# DO NOT MODIFY THE LINES BELOW UNLESS YOU KNOW WHAT YOU ARE DOING
export CA_ROOT="$(pwd)/$CA_NAME"
export CA_SECT="openvpn_ca"
export SERVER_FQDN="${SERVER_NAME}.${SERVER_DOMAIN}"
