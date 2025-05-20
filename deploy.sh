#!/bin/bash

set -e  # Exit on any error

echo "░   ▒  ▓▐ Updating the system..."
sudo apt update

echo "░   ▒  ▓▐ Installing dependencies..."
sudo apt install -y docker.io docker-compose apache2-utils

echo "░   ▒  ▓▐ Creating necessary directories..."
mkdir -p data logs certs config

# Collect input from developer
read -p "🌐 Enter your Cloudflare API Email: " CF_EMAIL
read -p "🔑 Enter your Cloudflare DNS API Token: " CF_TOKEN
read -p "🆔 Enter your Cloudflare Zone ID: " CF_ZONE
read -p "🏷️  Enter your root domain (e.g., thevoyagerlab.xyz): " ROOT_DOMAIN
read -p "📛 How many subdomains do you want to configure (e.g., 2 for ddns, traefik)? " SUBDOMAIN_COUNT

# Collect subdomain names
declare -a SUBDOMAINS
for ((i=1; i<=SUBDOMAIN_COUNT; i++)); do
  read -p "➡️  Enter subdomain #$i (e.g., ddns): " SUB
  SUBDOMAINS+=("$SUB")
done

# Create the .env file
echo "░   ▒  ▓▐ Generating .env file..."
cat <<EOF > .env
CLOUDFLARE_API_EMAIL=$CF_EMAIL
CLOUDFLARE_DNS_API_TOKEN=$CF_TOKEN
EOF

# Create data/config.json for DDNS updater
# Generate config.json with root domain and all subdomains
echo "░   ▒  ▓▐ Generating data/config.json file..."

CONFIG_FILE="data/config.json"
echo '{ "settings": [' > $CONFIG_FILE

# Root domain entry
cat <<EOF >> $CONFIG_FILE
  {
    "provider": "cloudflare",
    "zone_identifier": "$CF_ZONE",
    "domain": "$ROOT_DOMAIN",
    "ttl": 60,
    "token": "$CF_TOKEN",
    "ip_version": "ipv4"
  },
EOF

# Subdomains entries
for index in "${!SUBDOMAINS[@]}"; do
  SUB="${SUBDOMAINS[$index]}"
  COMMA=","
  if [[ "$index" == "$((SUBDOMAIN_COUNT - 1))" ]]; then
    COMMA=""  # No comma for the last element
  fi
  cat <<EOF >> $CONFIG_FILE
  {
    "provider": "cloudflare",
    "zone_identifier": "$CF_ZONE",
    "domain": "$SUB.$ROOT_DOMAIN",
    "ttl": 60,
    "token": "$CF_TOKEN",
    "ip_version": "ipv4"
  }$COMMA
EOF
done

echo '] }' >> $CONFIG_FILE

# Create external docker network (ignore if already exists)
echo "░   ▒  ▓▐ Creating external Docker network..."
sudo docker network inspect traefik-proxy-network >/dev/null 2>&1 || \
sudo docker network create traefik-proxy-network

# Spin up the stack
echo "░   ▒  ▓▐ Starting Docker stack..."
sudo docker-compose up -d

echo "░   ▒  ▓▐ Showing live logs..."
sudo docker-compose logs -f
