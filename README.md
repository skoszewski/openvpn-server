# OpenVPN CA

This set of scripts has been derived from the open source project available at [https://github.com/skoszewski/sk-ca-scripts](https://github.com/skoszewski/sk-ca-scripts).

The scripts make creating a CA, issuing client certificates, creating OpenVPN configuration files, and revoking the certificates easy.

## Setup

Review the `env.sh` file and make necessary changes. Add the following lines to the `[ req_dn ]` section of the `ca.conf` file, if you need more detailed distinguished names.

```conf
O = Example Company In.c
OU = IT
C = US
```

Run the `make-ca.sh` script to create a directory structure which will hold CA database. The CA root certificate will be created and self-signed.

## Operation

The `new-client.sh` script takes one argument and creates a client configuration. The client configuration contains an X.509 certificate issued for the client. The specified client name is used for the certificate's subject common name.

The certificate file is located in `<ca_root>/certs` directory, the private key in `<ca_root>/private` and OpenVPN configuration file in `<ca_root>/configs`. Ensure that OpenVPN configuration is kept secret because after installed enables the workstation to connect to the VPN without any other user input. The file should be installed in a directory accessible only to administrators, for example: `C:\Program Files\OpenVPN Connect\profiles`. You can secure the folder with the following commands:

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
