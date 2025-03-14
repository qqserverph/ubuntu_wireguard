#!/bin/bash

# --------------------------------------------
# Configuration Variables (Edit These!)
# --------------------------------------------
PIA_REGION="us_chicago"     # Change to your preferred region (e.g., "nl_amsterdam")
LAN_INTERFACE="eth1"        # Confirm LAN interface name with `ip a`
PIA_TOKEN_FILE="$HOME/pia_token"

# --------------------------------------------
# Kill Switch Setup (Blocks non-VPN Traffic)
# --------------------------------------------

# Function to set up kill switch rules
setup_kill_switch() {
  # Drop all forwarded traffic by default
  sudo iptables -P FORWARD DROP

  # Allow traffic ONLY through the VPN interface (wg0)
  sudo iptables -A FORWARD -i "$LAN_INTERFACE" -o wg0 -j ACCEPT
  sudo iptables -A FORWARD -i wg0 -o "$LAN_INTERFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT

  # Block LAN-to-WAN traffic (secondary safeguard)
  WAN_INTERFACE=$(ip route | grep default | awk '{print $5}')
  sudo iptables -A FORWARD -i "$LAN_INTERFACE" -o "$WAN_INTERFACE" -j DROP

  # Save rules
  sudo netfilter-persistent save
}

# --------------------------------------------
# Main Script
# --------------------------------------------

# Update system and install dependencies
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y wireguard resolvconf jq curl iptables-persistent

# Download PIA's WireGuard script
wget -O /tmp/pia-wireguard.sh https://raw.githubusercontent.com/qqserverph/manual-connections/refs/heads/master/connect_to_wireguard_with_token.sh
chmod +x /tmp/pia-wireguard.sh

# Generate PIA token (if missing)
if [ ! -f "$PIA_TOKEN_FILE" ]; then
  echo "Generating PIA token (first-time setup)..."
  /tmp/pia-wireguard.sh --generate-token-only
  mv /tmp/pia_token "$PIA_TOKEN_FILE"
fi

# Generate WireGuard config
sudo /tmp/pia-wireguard.sh --token=$(cat "$PIA_TOKEN_FILE") --region="$PIA_REGION"

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Configure NAT
sudo iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE

# Set up kill switch
setup_kill_switch

# Enable WireGuard on boot
WG_CONF_NAME=$(ls /etc/wireguard/PIA-*.conf | xargs basename | sed 's/.conf//')
sudo systemctl enable --now wg-quick@"$WG_CONF_NAME"

# Output Status
echo "----------------------------------------"
echo "VPN Router + Kill Switch Setup Complete!"
echo "----------------------------------------"
echo "LAN Interface: $LAN_INTERFACE"
echo "Clients will ONLY have internet access when WireGuard is active."
echo "Gateway IP for clients: $(ip -4 addr show $LAN_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
