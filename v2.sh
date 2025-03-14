#!/bin/bash

# ---------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------
PIA_USERNAME="YOUR_PIA_USERNAME"  # Replace with your PIA credentials
PIA_PASSWORD="YOUR_PIA_PASSWORD"
LAN_INTERFACE="eth1"              # Confirm with `ip a`
REGION="us_chicago"               # Change to preferred region

# ---------------------------------------------------------------
# Install Dependencies
# ---------------------------------------------------------------
sudo apt update -y
sudo apt install -y git wireguard iptables-persistent resolvconf

# ---------------------------------------------------------------
# Clone PIA's Official Scripts
# ---------------------------------------------------------------
git clone https://github.com/pia-foss/manual-connections.git
cd manual-connections

# ---------------------------------------------------------------
# Generate WireGuard Config (Official Method)
# ---------------------------------------------------------------
echo -e "$PIA_USERNAME\n$PIA_PASSWORD" | sudo ./run_setup.sh

# ---------------------------------------------------------------
# Get Generated Config
# ---------------------------------------------------------------
WG_CONF=$(ls /etc/wireguard/pia_* | head -1)
WG_CONF_NAME=$(basename $WG_CONF .conf)

# ---------------------------------------------------------------
# VPN Router Setup
# ---------------------------------------------------------------
# Enable IP Forwarding
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Configure NAT
sudo iptables -t nat -A POSTROUTING -o $WG_CONF_NAME -j MASQUERADE

# Kill Switch Rules
sudo iptables -P FORWARD DROP
sudo iptables -A FORWARD -i $LAN_INTERFACE -o $WG_CONF_NAME -j ACCEPT
sudo iptables -A FORWARD -i $WG_CONF_NAME -o $LAN_INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo netfilter-persistent save

# ---------------------------------------------------------------
# Enable on Boot
# ---------------------------------------------------------------
sudo systemctl enable --now wg-quick@$WG_CONF_NAME

# ---------------------------------------------------------------
# Output
# ---------------------------------------------------------------
echo "----------------------------------------"
echo "VPN Router Setup Complete!"
echo "----------------------------------------"
echo "LAN Interface: $LAN_INTERFACE"
echo "Clients should use: $(ip -4 addr show $LAN_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}') as gateway"
