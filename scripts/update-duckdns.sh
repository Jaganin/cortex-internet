#!/bin/bash
# Update DuckDNS with current public IP
# Add to cron: */5 * * * * /opt/cortex-internet/scripts/update-duckdns.sh >> /var/log/duckdns.log 2>&1

DOMAINS="jaganin"
DUCKDNS_TOKEN_FILE="/opt/cortex-internet/.env"

# Read token from .env
TOKEN=$(grep DUCKDNS_TOKEN "$DUCKDNS_TOKEN_FILE" | cut -d= -f2)

curl -s "https://www.duckdns.org/update?domains=${DOMAINS}&token=${TOKEN}&ip=" -o /tmp/duckdns_response

RESPONSE=$(cat /tmp/duckdns_response)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

if [ "$RESPONSE" = "OK" ]; then
  echo "[$TIMESTAMP] DuckDNS updated OK"
else
  echo "[$TIMESTAMP] DuckDNS ERROR: $RESPONSE"
fi
