# Basic variables 
export CA_NAME="openvpn-ca"
export CA_ROOT="$(pwd)/$CA_NAME"
export OPENVPN_BASEDIR="/etc/openvpn/server"

# Customize the company information below.
export SUBJ_O="Example Company Inc."
export SUBJ_OU="Shared IT"
export SUBJ_C="PL"

# OpenVPN server information
export SERVER_NAME="openvpn-poc"
export SERVER_FQDN="$SERVER_NAME.example.com"
export SERVER_WWW_PROTOCOL="https"
export SERVER_PROTOCOL="udp"
export SERVER_PORT="1194"

# CA information
export CA_CERT="$CA_ROOT/certs/$CA_NAME.crt"
export CA_KEY="$CA_ROOT/private/$CA_NAME-key.txt"
export CA_CRL="$CA_ROOT/$CA_NAME.crl"
