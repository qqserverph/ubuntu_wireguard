#!/bin/bash

# ---------------------------------------------------------------
# Interactive Credential Input (Secure)
# ---------------------------------------------------------------
clear
echo "PIA VPN Router Setup"
echo "--------------------"
read -p "Enter PIA Username: " PIA_USER
read -sp "Enter PIA Password: " PIA_PASS
echo -e "\n\n"

# ---------------------------------------------------------------
# Configuration (Verify Values!)
# ---------------------------------------------------------------
REGION="us_chicago"                # Change region as needed
LAN_INTERFACE="eth1"               # Confirm with `ip a`
LAN_IP="192.168.1.1"               # Router IP
SUBNET="192.168.1.0/24"            # Subnet
DHCP_RANGE="192.168.1.2,192.168.1.150"  # Client IP range

# ---------------------------------------------------------------
# Network Configuration
# ---------------------------------------------------------------
# Configure static IP for LAN interface
echo "[1/7] Configuring network..."
sudo tee /etc/netplan/01-vpn-router.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $LAN_INTERFACE:
      addresses: [$LAN_IP/24]
      dhcp4: no
EOF
sudo netplan apply

# ---------------------------------------------------------------
# Install Dependencies
# ---------------------------------------------------------------
echo "[2/7] Installing packages..."
sudo apt update -y
sudo apt install -y git wireguard iptables-persistent resolvconf dnsmasq

# ---------------------------------------------------------------
# DHCP Server Setup
# ---------------------------------------------------------------
echo "[3/7] Configuring DHCP..."
sudo tee /etc/dnsmasq.conf <<EOF
interface=$LAN_INTERFACE
dhcp-range=$DHCP_RANGE,255.255.255.0,24h
dhcp-option=option:router,$LAN_IP
dhcp-option=option:dns-server,1.1.1.1
EOF
sudo systemctl restart dnsmasq

# ---------------------------------------------------------------
# PIA WireGuard Setup
# ---------------------------------------------------------------
echo "[4/7] Setting up PIA VPN..."
git clone https://github.com/pia-foss/manual-connections.git
cd manual-connections

sudo ./run_setup.sh <<EOF
$PIA_USER
$PIA_PASS
$REGION
y
EOF

# ---------------------------------------------------------------
# VPN Routing & Killswitch
# ---------------------------------------------------------------
echo "[5/7] Configuring firewall..."
WG_CONF=$(sudo ls /etc/wireguard/pia_*.conf | head -1)
WG_CONF_NAME=$(basename "$WG_CONF" .conf)

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Configure NAT and killswitch
sudo iptables -t nat -A POSTROUTING -o "$WG_CONF_NAME" -j MASQUERADE
sudo iptables -P FORWARD DROP
sudo iptables -A FORWARD -i "$LAN_INTERFACE" -o "$WG_CONF_NAME" -j ACCEPT
sudo iptables -A FORWARD -i "$WG_CONF_NAME" -o "$LAN_INTERFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo netfilter-persistent save

# ---------------------------------------------------------------
# Enable Services
# ---------------------------------------------------------------
echo "[6/7] Starting services..."
sudo systemctl enable --now "wg-quick@$WG_CONF_NAME"

# ---------------------------------------------------------------
# Completion
# ---------------------------------------------------------------
echo -e "\n\n[7/7] Setup complete!"
echo "----------------------------------------"
echo "Router IP: $LAN_IP"
echo "Clients will get IPs: $DHCP_RANGE"
echo "Test VPN: curl ifconfig.me"
echo "----------------------------------------"
