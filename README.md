# OpenVPN CA

This set of scripts has been derived from the open source project available at [https://github.com/skoszewski/sk-ca-scripts](https://github.com/skoszewski/sk-ca-scripts).

The scripts are:

* `env.sh` - common variables
* `make-ca.sh` - make CA and issue a server certificate.
* `new-client.sh` - register a new client, issue a certificate and compose an OpenVPN profile.
* `list-clients.sh` - list currently active clients with an optional name filter.
* `show-client.sh` - print the client OpenVPN profile or the certificate to the screen.
* `remove-client.sh` - remove the client information, revoke its certificate and generate a new CRL.
* `show-crl.sh` - print the textual representation of the CRL

## Setup

Review the `env.sh` file and make necessary changes. At least customize `SUBJ_*` and `SERVER_*` variables.

```conf
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
```

Run the `make-ca.sh` script to create a directory structure which will hold CA database. The CA root and the server certificate will be created.

## Operation

### Create a new client

Use the `new-client.sh` script to create a new client profile. The script takes one required and two optional arguments.

Usage:

```text
./new-client.sh -n <client_name> [ -b <base_name> ] [ -s <device_serial_number> ]
```

* `client_name` - the generic description/name of the client.
* `base_name` - an optional base name for certificate and OpenVPN profile files. You can only use lower case letters, numbers and an underscore. The name must start with a letter. The base name will be automatically generated from the client name if a `base_name` is not specified.
* `device_serial_number` - the device's serial number.

The certificate file is located in `<ca_root>/certs` directory, the private key in `<ca_root>/private` and OpenVPN configuration file in `<ca_root>/profiles`. Ensure that OpenVPN configuration is kept secret because after installed enables the workstation to connect to the VPN without any other user input. The file should be installed in a directory accessible only to administrators, for example: `C:\Program Files\OpenVPN Connect\profiles`. You can secure the folder with the following commands:

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
