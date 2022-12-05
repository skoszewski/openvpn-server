#!/usr/bin/env bash

# Include function definitions
. functions.sh

# Define functions
usage() {
    echo "Usage: $(basename $0) [ -s <server_fqdn> ] [ -r ] [ -c ] [ -o ] [ -f ] ..."
    echo "       [ -t ] [ -n <n_vpn_processes> ] [ -d <certificate description> ] ..."
    echo "       [ -a <network/mask> ] [ -i <interface_ip> ] [ -l <network/mask> ] ... "
}

unset FORCE ROOT_CA COPY_ONLY SUBJ_DESC CERT_ONLY TUNNEL_ALL
unset N_VPN_PROCESSES ADDRESS_SPACE INTERFACE_IP LOCAL_NETWORK

while getopts "hs:rcoftn:d:a:i:l:" option
do
    case $option in
        r)
            ROOT_CA=1
            ;;
        s)
            # Check, if the specified parameter is a valid FQDN
            if echo $OPTARG | grep -q -E '^([a-zA-Z0-9_-]+\.)+[a-zA-Z0-9_-]+$'
            then
                SERVER_FQDN="$OPTARG"
                SERVER_NAME="${SERVER_FQDN%%.*}"
            else
                echo "ERROR: The specified server name \"$OPTARG\" is not a valid FQDN."
                exit 1
            fi
            ;;
        c)
            COPY_ONLY=1
            ;;
        d)
            SUBJ_DESC="$OPTARG"
            ;;
        o)
            CERT_ONLY=1
            ;;
        f)
            FORCE=1
            ;;
        n)
            N_VPN_PROCESSES="$OPTARG"
            ;;
        a)
            if echo "$OPTARG" | grep -q -v -E '^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$'
            then
                echo "ERROR: Please enter the VPN address-space in the format of a.b.c.d/n."
                exit 1
            fi
            ADDRESS_SPACE="$OPTARG"
            ;;
        i)
            INTERFACE_IP="$OPTARG"
            ;;

        l)
            if echo "$OPTARG" | grep -q -v -E '^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$'
            then
                echo "ERROR: Please enter the local network in the format of a.b.c.d/n."
                exit 1
            fi
            LOCAL_NETWORK="$OPTARG"
            ;;
        t)
            TUNNEL_ALL=1
            ;;
        h)
            usage
            exit 0
    esac
done

# Check, if the environment has been sourced. Stop, if not.
check_env -v || exit 1

# Use FQDN with replaced dots and dashes as a base name for files.
BASE_NAME="${SERVER_FQDN//./_}"

# Define server certificate files
REQ_FILE="$CA_ROOT/certs/$BASE_NAME.req"
CERT_FILE="$CA_ROOT/certs/$BASE_NAME.crt"
KEY_FILE="$CA_ROOT/private/$BASE_NAME-key.txt"

# Check, if the certificate already exists
if check_cert "$CERT_FILE"
then
    if [ -z "$COPY_ONLY" ]
    then
        echo "ERROR: The certificate for $SERVER_FQDN already exists."
        exit 1
    fi

    echo "NOTICE: Using the existing certificate."
else
    # Compose a subject name
    # Add a description if explictly defined or the certificate will be issued
    # for the local OpenVPN service
    if [ -n "$SUBJ_DESC" ] || [ -z "$CERT_ONLY" ]
    then
        build_subject_name "$SERVER_FQDN" "${SUBJ_DESC:-OpenVPN Server Certificate}"
    else
        # or build a subject name without a description
        build_subject_name "$SERVER_FQDN"
    fi

    # Create a server certificate request
    if openssl req -out "$REQ_FILE" -newkey rsa:2048 -nodes -keyout "$KEY_FILE" -config ca.conf -subj "$SUBJECT_NAME" -addext "subjectAltName=DNS:$SERVER_FQDN"
    then
        # Sign the request (suppress output)
        if ! openssl ca -in "$REQ_FILE" -out "$CERT_FILE" -notext -config ca.conf -extensions server_ext -batch
        then
            echo "ERROR: Cannot sign the server certificate request."
            exit 1
        fi

        # Remove the request file
        rm -f "$REQ_FILE"
    else
        echo "ERROR: Cannot create a server certificate request."
        exit 1
    fi

    echo "NOTICE: Issued a certificate for $SERVER_FQDN."
fi

if [ -n "$OPENVPN_BASEDIR" ] && [ -z "$CERT_ONLY" ]
then
    echo "Creating server configuration files..."

    # Check, if a DH exists
    if [ ! -f "$CA_ROOT/private/${BASE_NAME}_dh.pem" ]
    then
        # No - create it.
        openssl dhparam -out "$CA_ROOT/private/${BASE_NAME}_dh.pem" 2048
    fi

    # Check, if the static TLS key exists
    if [ ! -f "$CA_ROOT/private/${BASE_NAME}_ta.key" ]
    then
        openvpn --genkey --secret "$CA_ROOT/private/${BASE_NAME}_ta.key"
    fi
    
    # Define CA certificate and CRL paths
    if [ -z "$ROOT_CA" ]
    then
        OPENVPN_CA_CERT="$OPENVPN_BASEDIR/ca.crt"
        OPENVPN_CRL="$OPENVPN_BASEDIR/crl.pem"
    else
        HASH="$(openssl x509 -in "$CA_ROOT/$CA_NAME.crt" -noout -subject_hash)"
        OPENVPN_CA_CERT="$OPENVPN_BASEDIR/$HASH.0"
        OPENVPN_CRL="$OPENVPN_BASEDIR/$HASH.r0"
    fi

    ### Create the common configuration file.
    cat > "$CA_ROOT/private/${BASE_NAME}_common.inc" <<END
# Basic configuration
dev tun
topology subnet

mode server
tls-server
push "topology subnet"
client-config-dir client-config

auth SHA256
cipher AES-256-CBC

# Authentication and encryption
;capath .
ca ca.crt
crl-verify crl.pem
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0

# Other
keepalive 10 120
persist-key
persist-tun

user nobody
group nogroup

verb 3
END

    # Push route to the local network, if specified.
    if [ -n "$LOCAL_NETWORK" ]
    then
        LOCAL_NET_ADDRESS=$( echo $LOCAL_NETWORK | cut -d/ -f1 )
        LOCAL_NET_MASK=$( echo $LOCAL_NETWORK | cut -d/ -f2 )
        MASK=$( convert_mask_length_to_bytes $LOCAL_NET_MASK )

        cat >> "$CA_ROOT/private/${BASE_NAME}_common.inc" <<END

push "route $LOCAL_NET_ADDRESS $MASK"
END
    fi

    # Push redirect-gateway option to enable tunnel-all functionality.
    if [ -n "$TUNNEL_ALL" ]
    then
        cat >> "$CA_ROOT/private/${BASE_NAME}_common.inc" <<END

push "redirect-gateway def1"
END
    fi
    
    # Check, if the server is running multiple interfaces
    if [ $( ip -4 addr show | awk '/^\s+inet/ && $2 !~ /^127\.0\.0/ { print $2 }' | wc -l ) -gt 1 ]
    then
        echo "WARNING: More than one active interface detected. Using only the first one."
        echo "         Please check the file and adjust interface IP, if necessary."
    fi

    # Get the IP address of the first non-local interface.
    INTERFACE_IP=${INTERFACE_IP:-$( ip -4 addr show | awk '/^\s+inet/ && $2 !~ /^127\.0\.0/ { print $2 }' | head -1 | cut -d/ -f1 )}

    # Check, if the number of VPN processes has been specified,
    # and then generate configuration files.
    if [ -n "$N_VPN_PROCESSES" ]
    then
        # Assign the default, if not specified.
        ADDRESS_SPACE=${ADDRESS_SPACE:-10.0.0.0/24}

        # Calculate the network address and the mask length
        # Use default 10.0.0.0/24, if not specified.
        NETWORK=$(echo $ADDRESS_SPACE | cut -d/ -f1)
        NETMASK_LENGTH=$(echo $ADDRESS_SPACE | cut -d/ -f2)

        # Calculate the number of bits that will create the
        # required number of subnets.
        n_bits=0

        while [ $N_VPN_PROCESSES -gt $(( 2**$n_bits )) ]
        do
            n_bits=$(( $n_bits + 1))
        done

        # Adjust the netmask length to accommodate the number of subnets per VPN process.
        NETMASK_LENGTH=$(( $NETMASK_LENGTH + $n_bits ))
        SUBNET_IPS=$(( 2**(32 - $NETMASK_LENGTH) ))
        N_HOSTS=$(( $SUBNET_IPS - 2))
        NETMASK=$( convert_mask_length_to_bytes $NETMASK_LENGTH )

        # Convert network address to a number
        network_n=$( convert_quadbytes_to_integer $NETWORK )

        # Calculate subnets
        i=0
        while [ $i -lt $N_VPN_PROCESSES ]
        do
            INSTANCE_NAME="${SERVER_PROTOCOL}-${SERVER_PORT}"
            test $i -gt 0 && INSTANCE_NAME="${INSTANCE_NAME}-$i"

            # Build configuration file path.
            CONFIG_FILE="$CA_ROOT/private/${BASE_NAME}_${INSTANCE_NAME}.conf"

            SUBNET=$( convert_integer_to_quadbytes $network_n )

            gw_a=$(( $network_n + 1 ))
            pool_start_a=$(( $network_n + 2 ))
            pool_end_a=$(( $network_n + $N_HOSTS ))
            gw_ip=$( convert_integer_to_quadbytes $gw_a )
            pool_start_ip=$( convert_integer_to_quadbytes $pool_start_a )
            pool_end_ip=$( convert_integer_to_quadbytes $pool_end_a )

            echo "Process #$(($i+1)): gateway IP: $gw_ip, pool start: $pool_start_ip, pool end: $pool_end_ip."

            cat > "$CONFIG_FILE" <<END
config common.inc

local $INTERFACE_IP
port $SERVER_PORT
proto ${SERVER_PROTOCOL/tcp/tcp-server}

ifconfig $gw_ip $NETMASK
push "route-gateway $gw_ip"
ifconfig-pool $pool_start_ip $pool_end_ip

log /var/log/openvpn/${INSTANCE_NAME}.log
END
            if [ "$SERVER_PROTOCOL" = "udp" ]
            then
                echo "explicit-exit-notify" >> "$CONFIG_FILE"
            fi
            
            i=$(( $i+1 ))
            network_n=$(( $network_n + $SUBNET_IPS))
        done
    fi

    # Create server specific iptables NAT configuration
    cat > "$CA_ROOT/private/${BASE_NAME}_before_rules.ufw" <<END
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s $ADDRESS_SPACE -o $IFACE -j MASQUERADE

COMMIT
END
    # Check, if the OpenVPN has been installed, and the configuration is for the local server.
    if [ -d "$OPENVPN_BASEDIR" ] && [ $(hostname -f) = "$SERVER_FQDN" ]
    then
        echo "Installing or updating OpenVPN server files..."

        # Create a directory for client configuration files
        sudo mkdir -p "$OPENVPN_BASEDIR/client-config"

        # Copy DH parameter file and TLS key file.
        sudo cp -uv "$CA_ROOT/private/${BASE_NAME}_dh.pem" "$OPENVPN_BASEDIR/dh.pem"
        sudo cp -uv "$CA_ROOT/private/${BASE_NAME}_ta.key" "$OPENVPN_BASEDIR/ta.key"
        
        # Copy server certificate and key
        sudo cp -uv "$CERT_FILE" "$OPENVPN_BASEDIR/server.crt"
        sudo cp -uv "$KEY_FILE" "$OPENVPN_BASEDIR/server.key"

        # Copy the CA certificate and the CRL
        sudo cp -uv "$CA_ROOT/$CA_NAME.crt" "$OPENVPN_CA_CERT"
        sudo cp -uv "$CA_ROOT/$CA_NAME.crl" "$OPENVPN_CRL"
    fi
fi
