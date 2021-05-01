#!/bin/sh
# This script will configure an OpenBSD -current (6.8)
# server with Wireguard and Web Rendering Proxy. It should be run as root.
#
# This script assumes the Wireguard server IP will be 10.1.1.1 and the
# client (peer) IP will be 10.1.1.2. Adjust these as you desire.
#
# Once wireguard-tools is installed, generate the private key with `wg genkey`
# Generate the public key with `echo privatekeygoeshere | wg pubkey`
#
# The private key will be placed in the /etc/wireguard/server.conf file we'll make.
# The public key will need to be supplied to the peer.
# Lastly, you'll need the peer's public key for that server.conf file too.
######################################################################

# Update existing packages, then install chromium and wireguard-tools
pkg_add -u
pkg_add chromium wireguard-tools

# Download and install WRP binary
ftp https://github.com/tenox7/wrp/releases/download/4.5.1/wrp-amd64-openbsd
install -m 755 wrp-amd64-openbsd /usr/local/bin

# Add a non-root user to run the WRP binary
useradd wrpuser

# Create wireguard interface. Modify the IP address as desired
touch /etc/hostname.wg0
cat <<EOF > /etc/hostname.wg0
10.1.1.1 255.255.255.0
!/usr/local/bin/wg setconf wg0 /etc/wireguard/server.conf
EOF

# Create wireguard conf directory and conf file. Allowed IP will be the client IP
mkdir /etc/wireguard
touch /etc/wireguard/server.conf
cat <<EOF > /etc/wireguard/server.conf
[Interface]
PrivateKey = pasteyourserverprivatekey
ListenPort = 51820

[Peer]
PublicKey = pasteyourclientpublickey
AllowedIPs = 10.1.1.2/32
EOF

# Configure firewall

cat <<EOF > /etc/pf.conf
set skip on { lo, wg }
int_ip = "10.0.0.0/8"

block drop      # block stateless traffic
pass in quick on egress proto tcp from any to egress:0 port 22
pass in quick on egress proto udp from any to egress:0 port 51820
pass in quick on 10.1.1.1 proto tcp from $int_ip to 10.1.1.1 port 80
pass out

block return in on ! lo0 proto tcp to port 6000:6010

block return out log proto {tcp udp} user _pbuild
EOF

# Use AdGuard DNS for adblocking
touch /etc/dhclient.conf
echo 'prepend domain-name-servers 176.103.130.130;' >> /etc/dhclient.conf

# Clean up
rm wrp-amd64-openbsd
echo 'Configuration done!'
echo 'Run `wg genkey` and paste the output into the PrivateKey section of /etc/wireguard/server.conf'
echo 'Run `echo privatekeygoeshere | wg pubkey` and provide the resulting public key to peer'
echo 'Add the peer public key to the [Peer] section of /etc/wireguard/server.conf'
echo 'Lastly, run `sh /etc/netstart` or reboot to apply all changes'