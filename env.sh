# Basic variables 
export CA_NAME="openvpn-ca"
export CA_ROOT="$(pwd)/$CA_NAME"
export OPENVPN_BASEDIR="/etc/openvpn/server"

# CA Name
export SUBJ_CN="OpenVPN CA 2022.03"

# OpenVPN server information
export SERVER_NAME="openvpn-poc"
export SERVER_PROTOCOL="udp"
export SERVER_PORT="1194"

# CA information
export CA_CERT="$CA_ROOT/certs/$CA_NAME.crt"
export CA_KEY="$CA_ROOT/private/$CA_NAME-key.txt"
export CA_CRL="$CA_ROOT/$CA_NAME.crl"
