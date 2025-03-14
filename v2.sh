#!/bin/bash

# ---------------------------------------------------------------
# Configuration (Edit these!)
# ---------------------------------------------------------------
export PIA_USER="YOUR_PIA_USERNAME"       # Replace with your credentials
export PIA_PASS="YOUR_PIA_PASSWORD"
LAN_INTERFACE="eth1"                      # Confirm with `ip a`
REGION="us_chicago"                       # Change region as needed

# ---------------------------------------------------------------
# Install Dependencies
# ---------------------------------------------------------------
sudo apt update -y
sudo apt install -y git wireguard iptables-persistent resolvconf

# ---------------------------------------------------------------
# Clone & Run PIA Script (Non-Interactive)
# ---------------------------------------------------------------
git clone https://github.com/pia-foss/manual-connections.git
cd manual-connections

# Force non-interactive mode with predefined region
sudo ./run_setup.sh <<EOF
$REGION
EOF

# ---------------------------------------------------------------
# Post-Configuration (same as before)
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
