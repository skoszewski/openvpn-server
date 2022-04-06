# OpenVPN access server and supporting CA

OpenVPN Access Server is a product name of the OpenVPN Inc. The *OpenVPN access server* (notice small caps) is a generic name for a VPN access server using OpenVPN software as a core service. Reliable operation of the OpenVPN access server requires a Public Key Infrastructure.

The following documentation describes both the CA setup and the OpenVPN access server setup. We will use Ubuntu LTS operating system without any external software dependencies.

Setup a VM running **18.04 LTS** or **20.04 LTS** Ubuntu releases. Copy the scripts to a directory not accessible by any other users.

> NOTE: You should not allow any non-admin logins to the server.

## CA Setup

This set of scripts has been derived from the open source project available at [https://github.com/skoszewski/sk-ca-scripts](https://github.com/skoszewski/sk-ca-scripts).

The scripts are:

* `*.env` - shell environment initialization files.
* `make-ca.sh` - make CA and issue a server certificate.
* `new-client.sh` - register a new client and issue a certificate.
* `list-clients.sh` - list currently active clients with an optional name filter.
* `show-client.sh` - print the client OpenVPN profile or the certificate to the screen.
* `remove-client.sh` - remove the client information, revoke its certificate and generate a new CRL.
* `show-crl.sh` - print the textual representation of the CRL
* `new-server.sh` - register a new server and issue a certificate.
* `remove-server.sh` - remove the server information, revoke its certificate and generate a new CRL.

### Initialization

Review the `env.sh` file and make necessary changes. At least customize `SUBJ_*` and `SERVER_*` variables.

```conf
# Basic variables 
export CA_NAME="openvpn-ca"
export CA_LONGNAME="OpenVPN CA"
export CA_ROOT="$(pwd)/$CA_NAME"
export CA_SECT="openvpn_ca"

# Customize the company information below.
export SUBJ_O="Example Company Inc."
export SUBJ_OU="Shared IT"
export SUBJ_C="PL"

# CRL and AIA server information
export SERVER_NAME="openvpn-poc"
export SERVER_FQDN="$SERVER_NAME.example.com"
export SERVER_WWW_PROTOCOL="https"

# OpenVPN server information
export OPENVPN_BASEDIR="/etc/openvpn/server"
export SERVER_PROTOCOL="udp"
export SERVER_PORT="1194"
```

Run the `make-ca.sh` script to create a directory structure which will hold CA database. The CA root and the server certificate will be created.

### Create a new client

Use the `new-client.sh` script to create a new client profile. The script takes one required and two optional arguments.

Usage:

```text
./new-client.sh -n <client_name> [ -b <base_name> ] [ -s <device_serial_number> ]
```

* `client_name` - the generic description/name of the client.
* `base_name` - an optional base name for certificate and OpenVPN profile files. You can only use lower case letters, numbers and an underscore. The name must start with a letter. The base name will be automatically generated from the client name if a `base_name` is not specified.
* `device_serial_number` - the device's serial number.

The certificate file is located in `<ca_root>/certs` directory, the private key in `<ca_root>/private` and OpenVPN configuration file is dynamically generated and printed to the screen using the `show-client.sh` script. Ensure that OpenVPN configuration is kept secret because it enables the workstation to connect to the VPN without any other user input. The file should be installed in a directory accessible only to administrators, for example: `C:\Program Files\OpenVPN Connect\profiles` or `C:\Program Files\OpenVPN\config`. You can secure the folder with the following commands:

```
mkdir "C:\Program Files\OpenVPN Connect\profiles"
icacls "C:\Program Files\OpenVPN Connect\profiles" /grant *S-1-5-19:f
icacls "C:\Program Files\OpenVPN Connect\profiles" /grant *S-1-5-32-544:f
icacls "C:\Program Files\OpenVPN Connect\profiles" /inheritance:r
```

Check, if the access control list is correct:

```
icacls "C:\Program Files\OpenVPN Connect\profiles"
```

The result should look like below:

```text
C:\Program Files\OpenVPN Connect\profiles NT AUTHORITY\SYSTEM:(F)
                                          BUILTIN\Administrators:(F)

Successfully processed 1 files; Failed processing 0 files
```

### List clients

The script `list-clients.sh` prints all active clients. An optional `-f` parameter takes one argument - an extended regular expression which will be used to filter clients.

### Show client information

The script `show-client.sh` prints the client's OpenVPN profile to the screen.

Usage:

```text
./show-client.sh { -n <client_name> | -b <base_name> } [ -c ]
```

The `client_name` or `base_name` must be specified. An optional parameter `-c` istructs the script to print the certificate information instead of the OpenVPN profile.

### Permanently disabling clients

The script `remove-client.sh` will revoke the client's certificate and remove OpenVPN profile and certificate files. The script will prompt the operatore before commencing the removal. The operation is irreversible.

Usage:

```
./remove-client.sh -n { <client_name> | -b <base_name> }"
```

### Print the certificate revocation list

Use `show-crl.sh` script to display the current certificate revocation list. The script takes no arguments.

## OpenVPN Access Server Setup

Install the `openvpn` package:

```shell
apt -y install openvpn
```

Install optional authentication modules, if you intend to use addition user authentication besides the client certificates.

```shell
apt -y install openvpn-auth-ldap
apt -y install openvpn-auth-radius
```

Create OpenVPN server configuration files in `/etc/openvpn/server` directory (Ubuntu 20.04 LTS).

Common configuration for all the running daemons on the same server - `common.inc`:

```ini
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

# Routes
push "route 192.168.4.0 255.255.255.0"

# Other
keepalive 10 120
persist-key
persist-tun
explicit-exit-notify

user nobody
group nogroup

verb 3
```

At least one instance configuration file. Use the following template for naming convention:

`<protocol>-<port>.conf`

An example:

`udp-1194.conf`

for a daemon running on port `1194` and using UDP protocol. The following example configures a daemon running on a host with the IP `192.168.10.30` (WAN-side). The local network is `192.168.4.0/24` and the VPN pool has been assigned from the `192.168.233.0/24` network. The VPN dynamic IP pool range has been reduced to `192.168.233.100 - 192.168.233.199`.

```ini
config common.inc

local 192.168.10.30
port 1194
proto udp

ifconfig 192.168.233.1 255.255.255.0
push "route-gateway 192.168.233.1"
ifconfig-pool 192.168.233.100 192.168.233.199

log /var/log/openvpn/udp-1194.log
```

Uncomment the following line in the `/etc/sysctl.conf` file:

```
net.ipv4.ip_forward=1
```

Initialize the CA and issue a server certificate. All deamons will use the same certificate.

Configura OpenVPN service for the defined daemon(s).

```shell
sudo systemctl enable --now openvpn-server@udp-1194
sudo systemctl status openvpn-server@udp-1194
```

You should have the OpenVPN daemons up and running.
