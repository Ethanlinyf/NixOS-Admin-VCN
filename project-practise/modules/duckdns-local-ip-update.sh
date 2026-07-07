#!/usr/bin/env bash
# DuckDNS updater (nixdeploy version - kept for compatibility with existing tars etc.)
# Secrets under /etc/nixdeploy/secrets (as used by other modules in this repo)

set -euo pipefail

SECRETS_DIR="/etc/nixdeploy/secrets"

SUBDOMAIN=$(cat "$SECRETS_DIR/duckdns-subdomain" 2>/dev/null || echo "missing")
TOKEN=$(cat "$SECRETS_DIR/duckdns-token" 2>/dev/null || echo "missing")

# Robust way to get the source IPv4 address for the default route.
LOCAL_IP=$(ip -4 route get 8.8.8.8 2>/dev/null | sed -n 's/.*src \([0-9.]*\).*/\1/p' | head -1)

# Fallback / alternative if you want the public/WAN IP instead of LAN IP
# LOCAL_IP=$(curl -s --max-time 5 https://ipv4.icanhazip.com || curl -s --max-time 5 https://api.ipify.org || echo "")

if [ -z "$LOCAL_IP" ] || [ "$SUBDOMAIN" = "missing" ] || [ "$TOKEN" = "missing" ]; then
  echo "ERROR: Failed to detect local IP or read DuckDNS secrets from $SECRETS_DIR" >&2
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: missing secrets or IP (LOCAL_IP=[$LOCAL_IP] SUBDOMAIN=[$SUBDOMAIN])" >> /var/log/duckdns.log
  exit 1
fi

# Ensure log file exists and is writable
touch /var/log/duckdns.log 2>/dev/null || true

printf '[%s] Detected local IP: %s for subdomain: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$LOCAL_IP" "$SUBDOMAIN" >> /var/log/duckdns.log

RESPONSE=$(curl -s --max-time 10 "https://www.duckdns.org/update?domains=$SUBDOMAIN&token=$TOKEN&ip=$LOCAL_IP" | tr -d ' \t\r\n')
printf 'DuckDNS response: [%s]\n' "$RESPONSE" >> /var/log/duckdns.log

# DuckDNS returns OK on success or nochg when IP is unchanged.
if [[ "$RESPONSE" == "OK" || "$RESPONSE" == "nochg" ]]; then
  printf 'DuckDNS updated successfully (response: %s) with IP: %s\n' "$RESPONSE" "$LOCAL_IP" >> /var/log/duckdns.log
  exit 0
else
  echo "ERROR: DuckDNS update failed with response: [$RESPONSE]" >&2
  exit 1
fi
