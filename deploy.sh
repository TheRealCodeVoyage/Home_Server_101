#!/bin/bash

set -e  # Exit on any error

echo "░   ▒  ▓▐ Updating the system..."
sudo apt update

echo "░   ▒  ▓▐ Installing dependencies..."
sudo apt install -y docker.io docker-compose

echo "░   ▒  ▓▐ Creating necessary directories..."
mkdir -p data logs certs config

# Collect input from developer
read -p "🌐 Enter your Cloudflare API Email: " CF_EMAIL
read -p "🔑 Enter your Cloudflare DNS API Token: " CF_TOKEN
read -p "🆔 Enter your Cloudflare Zone ID: " CF_ZONE
read -p "🌐  Root domain (e.g., thevoyagerlab.xyz): " ROOT_DOMAIN
read -p "🚀  Traefik sub-domain   [default: traefik]: " TRAEFIK_SUB
TRAEFIK_SUB=${TRAEFIK_SUB:-traefik}
read -p "🔄  DDNS sub-domain      [default: ddns]: " DDNS_SUB
DDNS_SUB=${DDNS_SUB:-ddns}

TRAEFIK_FQDN="${TRAEFIK_SUB}.${ROOT_DOMAIN}"
DDNS_FQDN="${DDNS_SUB}.${ROOT_DOMAIN}"

echo "🛠  Updating Host() rules in docker-compose.yml …"

# Traefik routers
sed -i "s|traefik\.http\.routers\.traefik-http\.rule=Host(\`.*\`)|traefik.http.routers.traefik-http.rule=Host(\`$TRAEFIK_FQDN\`)|" docker-compose.yml

sed -i "s|traefik\.http\.routers\.traefik-https\.rule=Host(\`.*\`)|traefik.http.routers.traefik-https.rule=Host(\`$TRAEFIK_FQDN\`)|" docker-compose.yml

# DDNS rules
sed -i "s|traefik\.http\.routers\.ddns-updater-http\.rule=Host(\`.*\`)|traefik.http.routers.ddns-updater-http.rule=Host(\`$DDNS_FQDN\`)|" docker-compose.yml

sed -i "s|traefik\.http\.routers\.ddns-updater-https\.rule=Host(\`.*\`)|traefik.http.routers.ddns-updater-https.rule=Host(\`$DDNS_FQDN\`)|" docker-compose.yml

echo "✅  Host rules updated:"
echo "    • Traefik → ${TRAEFIK_FQDN}"
echo "    • DDNS    → ${DDNS_FQDN}"

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

# Root domain entry
cat <<EOF >> $CONFIG_FILE
{ "settings": [
    {
    "provider": "cloudflare",
    "zone_identifier": "$CF_ZONE",
    "domain": "$ROOT_DOMAIN",
    "ttl": 60,
    "token": "$CF_TOKEN",
    "ip_version": "ipv4"
    },{
    "provider": "cloudflare",
    "zone_identifier": "$CF_ZONE",
    "domain": "${TRAEFIK_FQDN}",
    "ttl": 60,
    "token": "$CF_TOKEN",
    "ip_version": "ipv4"
    },{
    "provider": "cloudflare",
    "zone_identifier": "$CF_ZONE",
    "domain": "${DDNS_FQDN}",
    "ttl": 60,
    "token": "$CF_TOKEN",
    "ip_version": "ipv4"
    }
] }
EOF


# Create external docker network (ignore if already exists)
echo "░   ▒  ▓▐ Creating external Docker network..."
sudo docker network inspect traefik-proxy-network >/dev/null 2>&1 || \
sudo docker network create traefik-proxy-network

sleep 1

# Spin up the stack
echo "░   ▒  ▓▐ Starting Docker stack..."
sudo docker-compose up -d

echo "░   ▒  ▓▐ Showing live logs..."
sudo docker-compose logs -f
