#!/bin/bash

# ---------------------------------------------------------------
# Configuration (REPLACE THESE!)
# ---------------------------------------------------------------
read -p "Enter your PIA username: " PIA_USER
read -sp "Enter your PIA password: " PIA_PASS
echo
REGION="us_chicago"  # Find regions: https://serverlist.piaservers.net/vpninfo/servers/v6
LAN_INTERFACE="eth1" # Confirm with `ip a`

# ---------------------------------------------------------------
# Automated Setup (No Input Spam)
# ---------------------------------------------------------------
# Clone PIA's repo
git clone https://github.com/pia-foss/manual-connections.git
cd manual-connections

# Feed inputs in EXACT order: username → password → region → confirm (y)
sudo ./run_setup.sh <<EOF
$PIA_USER
$PIA_PASS
$REGION
y
EOF

# ---------------------------------------------------------------
# Post-Setup (Same as Manual Method)
# ---------------------------------------------------------------
WG_CONF=$(sudo ls /etc/wireguard/pia_*.conf | head -1)
WG_CONF_NAME=$(basename $WG_CONF .conf)

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Configure NAT and killswitch
sudo iptables -t nat -A POSTROUTING -o $WG_CONF_NAME -j MASQUERADE
sudo iptables -P FORWARD DROP
sudo iptables -A FORWARD -i $LAN_INTERFACE -o $WG_CONF_NAME -j ACCEPT
sudo iptables -A FORWARD -i $WG_CONF_NAME -o $LAN_INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo netfilter-persistent save

# Enable WireGuard
sudo systemctl enable --now wg-quick@$WG_CONF_NAME

echo "----------------------------------------"
echo "VPN Router Setup Complete!"
echo "----------------------------------------"
