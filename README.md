# OpenVPN access server and supporting CA

OpenVPN Access Server is a product name of the OpenVPN Inc. The *OpenVPN access server* (notice small caps) is a generic name for a VPN access server using OpenVPN software as a core service. Reliable operation of the OpenVPN access server requires a Public Key Infrastructure.

The following documentation describes both the CA setup and the OpenVPN access server setup. We will use Ubuntu LTS operating system without any external software dependencies.

Setup a VM running **LTS** Ubuntu releases. Copy the scripts to a directory not accessible by any other users.

```bash
git clone https://github.com/skoszewski/openvpn-server $HOME/openvpn-server
```

> NOTE: You should not allow any non-admin logins to the server.

## Operating System Configuration

Install the required packages:

```shell
sudo apt -y install nginx ssl-cert openvpn
```

Install optional authentication modules, if you intend to use addition user authentication besides the client certificates.

```shell
sudo apt -y install openvpn-auth-ldap openvpn-auth-radius
```

> NOTE: The configuration of the OpenVPN user authentication is currently beyond the scope of that document.

Use `snap` to install **certbot**.

```bash
sudo snap install certbot
```

> NOTE: On recent Ubuntu releases the certbot package is also available as a native Debian package, however the snap version may be newer and has more options.

Register an account in Let's Encrypt replacing `e-mail-name@example.com` with a shared or service mailbox address. Do not use your personal e-mail, if possible.

```bash
sudo certbot register -m e-mail-name@example.com --agree-tos
```

Check, if the firewall is configured and allows HTTP and HTTPS connections:

```bash
sudo certbot certonly --dry-run -d servername.example.com
```

Correct issues, if necessary and request a certificate:

```bash
sudo certbot run --nginx -d servername.example.com
```

> NOTE: You can specify more than one name using multiple `-d` options. The first one will be used for the common name and the rest for additional subject alternative names.

The `certbot` command will modify **NGINX** configuration and will install the certificate. If you have a custom configuration, use the following command:

```bash
sudo certbot certonly --webroot --webroot-path /var/www/html -d servername.example.com
```

and then install the certificate yourself. You will find it in `/etc/letsencrypt/live/servername.example.com`.

Please refer to the [Official Certbot documentation](https://eff-certbot.readthedocs.io/en/stable/using.html), if you need to use a different scenario.

## CA Setup

This set of scripts has been derived my other open source project: [https://github.com/skoszewski/sk-ca-scripts](https://github.com/skoszewski/sk-ca-scripts).

The scripts are:

* `*.env` - shell environment initialization files.
* `make-ca.sh` - make CA and issue a server certificate.
* `new-client.sh` - register a new client and issue a certificate.
* `new-server.sh` - register a new server and/or issue a certificate.
* `list-certificates.sh` - list certificates issued to clients and servers with an optional name filter.
* `show-certificate.sh` - print the certificate to the screen.
* `show-profile.sh` - print the OpenVPN client profile to the screen or save it to a file.
* `remove-client.sh` - revoke clients' certificate, remove files and generate a new CRL.
* `remove-server.sh` - revoke servers' certificate, remove files and generate a new CRL.
* `show-crl.sh` - print the textual representation of the CRL.
* `subnets.py` - calculate subnets of available address space.
* `publish-ca.sh` - publish CA AIA and CRL information.

### Initialization

copy `template.env` to `ca.env`, review it, and make necessary changes. Customize `CA_NAME`, `CA_LONGNAME`, `SUBJ_*` and `SERVER_*` variables.

```conf
# Basic variables 
export CA_NAME="openvpn-ca"
export CA_LONGNAME="OpenVPN CA"

# Customize the company information below.
export SUBJ_O="Example Company Inc."
export SUBJ_OU="IT"
export SUBJ_C="PL"

# CRL and AIA server information
export SERVER_NAME="openvpn-poc"
export SERVER_DOMAIN="example.com"
export SERVER_WWW_PROTOCOL="http"

# Uncomment the lines below, to enable publishing of CA certificates and/or profiles.
#export SERVER_CA_DIRECTORY="/var/www/html"
#export SERVER_PROFILE_DIRECTORY="/var/www/html/profiles"

# OpenVPN server information
export OPENVPN_BASEDIR="/etc/openvpn/server"
export SERVER_PROTOCOL="udp"
export SERVER_PORT="1194"

# DO NOT MODIFY THE LINES BELOW UNLESS YOU KNOW WHAT YOU ARE DOING
export CA_ROOT="$(pwd)/$CA_NAME"
export CA_SECT="openvpn_ca"
export SERVER_FQDN="${SERVER_NAME}.${SERVER_DOMAIN}"
```

Run the `make-ca.sh` script to create a directory structure which will hold CA database. The CA root certificate will be created.

> NOTE: The current year and month number will be added to the CA subject common name.

Run `new-server.sh` script without parameters to create server configuration and issue the server certificate.

### Creating a new client

Use the `new-client.sh` script to create a new client profile. The script takes one required and two optional arguments.

Usage:

```text
./new-client.sh -n <client_name> [ -b <base_name> ] [ -s <device_serial_number> ]
```

* `client_name` - the generic description/name of the client.
* `base_name` - an optional base name for certificate and OpenVPN profile files. You can only use lower case letters, numbers and an underscore. The name must start with a letter. The base name will be automatically generated from the client name if a `base_name` is not specified.
* `device_serial_number` - the device's serial number.

The certificate file will be placed in `<ca_root>/certs` directory, and the private key in `<ca_root>/private`. OpenVPN configuration file is dynamically generated and printed to the screen using the `show-profile.sh` script. Go to the [next section](#browsing-client-and-server-database) to read about how to use the script.

Ensure that OpenVPN configuration is kept secret because it enables the workstation to connect to the VPN without any other user input. The file should be installed in a directory accessible only to administrators, for example: `C:\Program Files\OpenVPN Connect\profiles` or `C:\Program Files\OpenVPN\config`. You can secure the folder with the following commands:

```batch
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

### Browsing client and server database

The script `list-certificates.sh` prints all active issued certificates. An optional `-f` parameter takes one argument - an extended regular expression which will be used to filter certificates.

Use `show-certificate.sh` script to print information and the issued certificate.

Use `show-profile.sh` to print client profile to the screen.

Usage:

```text
Usage: $0 { -n <client_name> | -b <base_name> } [ -d <dirname> ]
          [ -f <filename> | -f - | -f ! ] [ -u <URL path> ]
          [ -p tcp|udp ] [ -P <n> ]
```

The `client_name` or `base_name` must be specified.

An optional `-d <dirname>` parameter istructs the script to save the profile to a file. The parameter takes a destination directory path. The file name is a random strin by default. Use `-f` to specify your own name or a special one. `!` used with `-f` will create a name based on certificate hash and the `-` will use the base name for the file name. The latter option is not recommended for Web publishing because it allows anyone to easily guess the profile download URL.

If you have configured the web server and a directory to publish profiles, you can use `-u` parameter to calculate an URL where the profile can be downloaded. The `-u` take an argument - an URL path that will be added to server's FQDN before appending the profile name.

The `-p` and `-P` parameters allows overriding default `udp/1194` used in a profile. Use `-p tcp -P 443` to use OpenVPN over HTTPS port with port sharing feature.

### Permanently disabling clients

The script `remove-client.sh` will revoke the client's certificate and remove OpenVPN profile and certificate files. The script will prompt the operatore before commencing the removal. The operation is irreversible.

Usage:

```
./remove-client.sh { -n <client_name> | -b <base_name> }"
```

### Print the certificate revocation list

Use `show-crl.sh` script to display the current certificate revocation list. The script takes no arguments.

### Publish CA information

The CA information and CRL may be published to the local web server. Define `SERVER_CA_DIRECTORY` variable in the enviroment file and point it to the server root directory. Use `publish-ca.sh` script to copy AIA and CRL files to the directory. Use `show-ca.sh` with `-u` to print the URL of the server.

Download the CA certificate to clients, if you want to use the web server to distribute profiles (use name hashing to provide some sort of security).

On Windows use the following command to add the certificate to machine trusted root certificates store. Remember to run the command in an elevated command prompt.

```batch
certutil -addstore "Root" "<certfile.crt>"
```

### Renewing certificates

The certificates will expire after a specified time period. Use the following procedure to renew client certificate.

1. Use `list-certificates.sh` script to look for client.
1. Use `show-certificate.sh` script to display client properties like the name, the base name and the serial number.
1. Use `remove-client.sh` script to revoke the client's certificate and remove the configuration.
1. Use `new-client.sh` script to create a new certificate for the client.
1. Use `show-profile.sh` script to display or publish the OpenVPN profile for the client.

Use `remove-server.sh` and `new-server.sh` without any parameters to renew the server certificate.

> NOTE: Close and reopen the web browsers using the system store (Edge, Chrome, Opera). The Firefox is not using the system certificate store and you have to add the certificate in the Firefox.

## OpenVPN server setup

Uncomment the following line in the `/etc/sysctl.conf` file:

```
net.ipv4.ip_forward=1
```

Load changed values:

```shell
sudo sysctl -p /etc/sysctl.conf
```

Create OpenVPN server configuration files in `/etc/openvpn/server` directory (Ubuntu 20.04 LTS).

Common configuration file for all the running daemons on the same server - `common.inc`:

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

# Push local network route(s) to clients
push "route 10.0.0.0 255.255.255.0"

# Other
keepalive 10 120
persist-key
persist-tun

user nobody
group nogroup

verb 3
```

At least one instance configuration file. Use the following template for naming convention:

`<protocol>-<port>.conf`

An example:

`udp-1194.conf`

for a daemon running on port `1194` and using UDP protocol. The following example configures a daemon running on a host with the IP `1.2.3.4` (WAN-side). The local network is `192.168.4.0/24` and the VPN pool has been assigned from the `192.168.233.0/24` network. The VPN dynamic IP pool range has been reduced to `192.168.233.100 - 192.168.233.199`.

```ini
config common.inc

local 1.2.3.4
port 1194
proto udp
explicit-exit-notify

ifconfig 192.168.233.1 255.255.255.0
push "route-gateway 192.168.233.1"
ifconfig-pool 192.168.233.100 192.168.233.199

log /var/log/openvpn/udp-1194.log
```

Configure OpenVPN services for the defined daemon(s).

```shell
sudo systemctl enable --now openvpn-server@udp-1194
sudo systemctl status openvpn-server@udp-1194
```

The default OpenVPN configuration will not work if your client is on restricted networks. You can workaround most of hotel, airport and guest network restrictions by using `tcp/443` port to connect to the OpenVPN Server. Add another file `tcp-443.conf` to `/etc/openvpn/server` and use the example below:

```ini
config common.inc

local 1.2.3.4
port 443
proto tcp-server
port-share 127.0.0.1 443

ifconfig 192.168.234.1 255.255.255.0
push "route-gateway 192.168.234.1"
ifconfig-pool 192.168.234.100 192.168.234.199

log /var/log/openvpn/tcp-443.log
```

> NOTE: Use the `port-share` directive only if you intend to use port sharing with the web server.

If you need to share the 443 port with the web server, configure it to bind to the local interface only.

Add lines with networks you want to route through VPN connection:

```
push "route 10.1.1.0 255.255.255.0"
push "route 10.1.2.0 255.255.255.0"
```

Optionally add DNS configuration:

```
push "dhcp-option DNS 10.1.1.5"
push "dhcp-option DNS 10.1.1.6"
```

> NOTE: Remember to disable **DNS fallback** in *Advanced Settings* of the **OpenVPN Connect** client. You won't be able to resolve DNS names for machines accessible through the VPN tunnel.

**NGINX**: edit the `/etc/nginx/sites-available/default` file and find the server configuration. Add loopback interface addresses to `listen` directives.

```conf
listen 127.0.0.1:443 ssl default_server;
listen [::1]:443 ssl default_server;
```

Restart the **NGINX** web server to apply changes.

```shell
sudo systemctl restart nginx
```

Start and check the OpenVPN daemon listening on port 443.

```shell
sudo systemctl enable --now openvpn-server@tcp-443
sudo systemctl status openvpn-server@tcp-443
```

Check for errors in web server or OpenVPN server logs.

Finally schedule regular CRL updates. OpenVPN clients may refuse to connect if the CRL is outdated.

Create a script in `/etc/cron.daily` named `update-openvpn-crl` and put the following commands in it:

```bash
#!/bin/bash

SERVER_DIR="/home/ubuntu/openvpn-server"

source $SERVER_DIR/ca.env
$SERVER_DIR/update-crl.sh -e -c >/dev/null 2>&1
```

Adjust `SERVER_DIR` to the directory where the scripts are checked out.

### Redirect all the traffic through the VPN

Add the following command to `common.inc` file:

```
push "redirect-gateway def1"
```

Enable forwarding in the system by changing the `/etc/sysctl.conf`. Find the line with `net.ipv4.ip_forward` uncomment it if necessary and set it to `1`.

Add the following lines to the top of the file `/etc/ufw/before.rules`:

```
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s 10.0.0.0/24 -o eth0 -j MASQUERADE

COMMIT
```

Enable forwarding on the firewall:

```bash
sudo ufw default allow FORWARD
sudo service ufw restart
```

Restart the server.
