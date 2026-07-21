# Deployment Guide

## Prerequisites

- Cortex server (Ubuntu 24.04) with public internet access
- DuckDNS account with token for `jaganin.duckdns.org`
- Ports 80 and 443 forwarded on the Freebox/Synology to Cortex (`192.168.1.120`)

## 1. Port forwarding

On the **Freebox** (or Synology if it's the NAT entry point), add:

| Protocol | External port | Internal IP     | Internal port |
|----------|--------------|-----------------|---------------|
| TCP      | 80           | 192.168.1.120   | 80            |
| TCP      | 443          | 192.168.1.120   | 443           |

## 2. Deploy on Cortex

```bash
# Clone and bootstrap (as root)
git clone https://github.com/Jaganin/cortex-internet.git /opt/cortex-internet
cd /opt/cortex-internet
bash scripts/install.sh
```

The script stops if `.env` is missing. Fill it in:

```bash
nano /opt/cortex-internet/.env
```

Required values:
```bash
DUCKDNS_TOKEN=<your token from duckdns.org>
AUTHELIA_JWT_SECRET=$(openssl rand -hex 32)
AUTHELIA_SESSION_SECRET=$(openssl rand -hex 32)
AUTHELIA_STORAGE_ENCRYPTION_KEY=$(openssl rand -hex 32)
```

## 3. Create Authelia user password

```bash
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate argon2 --password 'yourpassword'
```

Copy the `$argon2id$...` hash into `authelia/users_database.yml`, field `password`.

## 4. Set up Authelia TOTP

First start:
```bash
cd /opt/cortex-internet
docker compose up -d
```

Open `https://auth.jaganin.duckdns.org`, log in, and enroll your TOTP device (Google Authenticator / Bitwarden / etc.).

## 5. DuckDNS auto-update (cron)

```bash
chmod +x /opt/cortex-internet/scripts/update-duckdns.sh

# Add to crontab
crontab -e
# Add:
*/5 * * * * /opt/cortex-internet/scripts/update-duckdns.sh >> /var/log/duckdns.log 2>&1
```

## 6. Verify

```bash
# Check all containers are running
docker compose ps

# Check Traefik logs
docker compose logs traefik -f

# Test HTTPS
curl -I https://auth.jaganin.duckdns.org
```

## Additional services

### leboncoin-mcp

MCP server ([wydii/leboncoin-mcp](https://github.com/wydii/leboncoin-mcp)) exposing Leboncoin search to AI assistants. Built as a Docker image from the upstream source (not vendored in this repo — cloned once, gitignored):

```bash
cd /opt/cortex-internet
git clone https://github.com/wydii/leboncoin-mcp.git lbc-mcp
docker compose up -d --build leboncoin-mcp
```

The `dockerfile_inline` in `docker-compose.yml` builds the image directly from `./lbc-mcp` (requirements.txt + server.py). No host port is published — it's reached by Traefik over the `proxy` Docker network only.

Exposed at `https://leboncoin.jaganin.duckdns.org` (Authelia-protected) via `traefik/dynamic/services.yml`.

To update after an upstream change:
```bash
cd /opt/cortex-internet/lbc-mcp && git pull
cd /opt/cortex-internet && docker compose up -d --build leboncoin-mcp
```

## Updates

```bash
cd /opt/cortex-internet
git pull
docker compose pull
docker compose up -d
```
