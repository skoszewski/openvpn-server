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
