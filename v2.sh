#!/bin/bash

# ---------------------------------------------------------------
# Configuration (REPLACE THESE!)
# ---------------------------------------------------------------
read -p "Enter your PIA username: " PIA_USER
read -sp "Enter your PIA password: " PIA_PASS
echo

# List of PIA regions to test
regions=("us_chicago" "us_new_york" "us_silicon_valley" "us_seattle" "us_washington_dc")

# Function to get the ping time for a region
#get_ping_time() {
#  ping -c 3 $1.piaservers.net | tail -1| awk '{print $4}' | cut -d '/' -f 2
#}

# Determine the fastest region
fastest_region=""
fastest_time=9999
echo "Testing regions for latency..."
for region in "${regions[@]}"; do
  ping_time=$(get_ping_time $region)
  echo "Region: $region, Ping: $ping_time ms"
  if (( $(echo "$ping_time < $fastest_time" | bc -l) )); then
    fastest_time=$ping_time
    fastest_region=$region
  fi
done
echo "Fastest region is $fastest_region with a ping time of $fastest_time ms"

read -p "Enter your preferred PIA region (default is fastest region $fastest_region): " REGION
REGION=${REGION:-$fastest_region}

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

# ------------------------------------------------ ▋
