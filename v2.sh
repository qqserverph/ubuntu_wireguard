#!/bin/bash

# ---------------------------------------------------------------
# Configuration (Edit these!)
# ---------------------------------------------------------------
PIA_USER="YOUR_PIA_USERNAME"       # Replace with your credentials
PIA_PASS="YOUR_PIA_PASSWORD"
REGION="us_chicago"                # Check regions with ./get_region.sh
LAN_INTERFACE="eth1"               # Confirm with `ip a`

# ---------------------------------------------------------------
# Non-Interactive Setup (No Prompts)
# ---------------------------------------------------------------
git clone https://github.com/pia-foss/manual-connections.git
cd manual-connections

# Feed inputs in exact order: username → password → region → confirm
sudo ./run_setup.sh <<EOF
$PIA_USER
$PIA_PASS
$REGION
y
EOF

# ---------------------------------------------------------------
# Post-Setup (same as before)
# ---------------------------------------------------------------
WG_CONF=$(ls /etc/wireguard/pia_* | head -1)
WG_CONF_NAME=$(basename $WG_CONF .conf)

echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

sudo iptables -t nat -A POSTROUTING -o $WG_CONF_NAME -j MASQUERADE

sudo iptables -P FORWARD DROP
sudo iptables -A FORWARD -i $LAN_INTERFACE -o $WG_CONF_NAME -j ACCEPT
sudo iptables -A FORWARD -i $WG_CONF_NAME -o $LAN_INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo netfilter-persistent save

sudo systemctl enable --now wg-quick@$WG_CONF_NAME

echo "----------------------------------------"
echo "VPN Router Setup Complete!"
echo "----------------------------------------"
