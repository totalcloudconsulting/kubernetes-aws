# easy-openvpn

Based on easy-rsa. Added embed-key generation features. Create embed-style VPN certificates, keys, configs easily.

__Purpose of the project__

1. Deploy OpenVPN setup on Ubuntu/Debian OS in 5 minutes, 3 easy steps.
2. Easy EMBED-style OpenVPN config generation which contains everything: key, cert, config in __ONE file__ !
3. AWS Cloudformation / automation ready (don't ask for anything)

----------

# Prerequisites

Ububtu / Debian OS (or based on) server

__Install openvpn, git, zip__

```
sudo apt-get install openvpn zip git
```

__Clone__

```
cd ~
git clone https://github.com/tatobi/easy-openvpn.git
```


# Create openvpn/keygen folder

```
sudo mkdir -p /etc/openvpn/keygen

```

__1. Copy content to the folder__


```
sudo cp ~/easy-openvpn/keygen/* /etc/openvpn/keygen/
```


__Edit "vars" file__


```
sudo nano /etc/openvpn/keygen/vars
```

Scroll dow to the end of file and set up the following variables:

__!CHANGE SETTINGS HERE!__

```
############################################
# Configure these fields
############################################
export OPENVPN_CONF_DIR="/etc/openvpn"
export OPENVPN_LOG_DIR="/var/log/openvpn"
export KEY_SIZE=2048
export CA_EXPIRE=7300
export KEY_EXPIRE=7300
export CRL_EXPIRE=7300
export KEY_COUNTRY="CC"
export KEY_PROVINCE="CHANGE_PROVINCE"
export KEY_CITY="CHANGE_CITY"
export KEY_ORG="CHANGE_ORG"
export KEY_EMAIL="CHANGE_ORG_EMAIL"
export KEY_OU="CHANGE_OU"
export SERVER_ENDPOINT="CHANGE_SERVER_IP"
export SERVER_PORT_TCP="443"
export SERVER_PORT_UDP="1194"

```

__2. Setup the server at TCP 443 (SSL) port__


```
sudo su -
cd /etc/openvpn/keygen
./create-server-tcp-gw

START SERVER:
service openvpn@server-tcp-gw start
```

__3. Create embed style OpenVPN config/cert for client__

```
sudo su -
cd /etc/openvpn/keygen
./build-key-embed-commongw {cert.name.01}

```

Download ZIPPED key to client, unzip to openvpn config folder and __thats all__! 
After proper setup at client, ALL traffic is going through your server securely.

----------

# Revoke client cert
```
sudo su -
cd /etc/openvpn/keygen
./revoke-client {cert.name.01}
```


# Using with PKCS12

You can create PKCS12 (NOT embedded) certificates:

```
sudo su -
cd /etc/openvpn/keygen
./build-key-pkcs12-commongw {cert.name.01}
```

----------

# Using UDP / gatewayless (site-to-site)

Using through UDP means less overhead but maybe blocked by ISPs. It is better for S2S VPN.

__Additonal routing setup is required!__

Please read openvpn documentation how to edit ccd files and server routing.

# Server

```
sudo su -
cd /etc/openvpn/keygen
./create-server 

(or already exist by previous setup):
./build-key-server
```

# Keys

```
sudo su -
cd /etc/openvpn/keygen


PKCS12:
./build-key-pkcs12 {cert.name.02}

EMBED:

./build-key-embed {cert.name.02}

NORMAL:
./build-key {cert.name.02}

```

----------
# Purge

# !!! WARNING clean-all deletes everything !!!

```
sudo su -
cd /etc/openvpn/keygen
./clean-all
```

----------

Thank you for: easy-rsa project and jinnjo vgithub for pem-split.




