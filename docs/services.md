# Adding a new service

## Service running in Docker

Add labels to the service in `docker-compose.yml`:

```yaml
  myapp:
    image: myapp:latest
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.jaganin.duckdns.org`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=duckdns"
      - "traefik.http.routers.myapp.middlewares=authelia@docker,secure-headers@file"
      - "traefik.http.services.myapp.loadbalancer.server.port=8080"
```

## Service running natively on Cortex

Add a router + service block in `traefik/dynamic/services.yml`:

```yaml
http:
  services:
    myapp:
      loadBalancer:
        servers:
          - url: "http://localhost:<PORT>"

  routers:
    myapp:
      rule: "Host(`myapp.jaganin.duckdns.org`)"
      entrypoints:
        - websecure
      tls:
        certResolver: duckdns
      middlewares:
        - authelia
        - secure-headers
      service: myapp
```

Traefik hot-reloads dynamic config — no restart needed.

## Bypassing auth for a service

In `authelia/configuration.yml`, add a bypass rule **before** the wildcard rule:

```yaml
access_control:
  rules:
    - domain: "myapp.jaganin.duckdns.org"
      policy: bypass
    - domain: "*.jaganin.duckdns.org"
      policy: two_factor
```

Remove the `authelia` middleware from the Traefik router as well.

## SSO via OIDC (preferred over ForwardAuth)

When a service supports OAuth2/OIDC natively, configure Authelia as the OIDC provider
instead of using ForwardAuth. This gives a real single sign-on experience (one Authelia
login covers all OIDC-enabled services).

### 1. Register the client in `authelia/configuration.yml`

```yaml
identity_providers:
  oidc:
    # hmac_secret via AUTHELIA_IDENTITY_PROVIDERS_OIDC_HMAC_SECRET env var
    jwks:
      - key_id: main
        algorithm: RS256
        use: sig
        key: |
          -----BEGIN PRIVATE KEY-----
          <RSA 2048 private key — generate with: openssl genrsa 2048>
          -----END PRIVATE KEY-----
    clients:
      - client_id: myapp
        client_name: MyApp
        # Hash with: docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password <secret>
        client_secret: '$argon2id$...'
        public: false
        authorization_policy: two_factor
        consent_mode: implicit
        pre_configured_consent_duration: 1y
        redirect_uris:
          - https://myapp.jaganin.duckdns.org/auth/login
        scopes:
          - openid
          - profile
          - email
        token_endpoint_auth_method: client_secret_post
```

Add a bypass rule for the service (Authelia ForwardAuth not needed — the service
handles auth via OIDC):

```yaml
access_control:
  rules:
    - domain: "myapp.jaganin.duckdns.org"
      policy: bypass
```

### 2. Traefik router — no `authelia` middleware

```yaml
  routers:
    myapp:
      middlewares:
        - secure-headers   # authelia NOT here — OIDC handles it
      service: myapp
```

### 3. Configure the service side

Point the service's OAuth settings to:
- **Issuer URL**: `https://auth.jaganin.duckdns.org`
- **Client ID / Secret**: as defined above

### ⚠️ Authelia file permissions

Authelia runs as root and writes to `/config` (mounted from `authelia/`), making files
root-owned. After any `git pull` that touches `authelia/`, fix permissions before
restarting:

```bash
docker run --rm -v /opt/cortex-internet/authelia:/config alpine chown -R 1000:1000 /config
```

---

## Services overview

| Service | URL | ForwardAuth | SSO OIDC | Notes |
|---------|-----|:-----------:|:--------:|-------|
| Jeedom | `jaganin.duckdns.org` / `jeedom.` | ❌ | ❌ | Auth Apache/Jeedom |
| Authelia | `auth.` | — | — | Portail auth |
| Traefik dashboard | `traefik.` | ✅ | ❌ | |
| qBittorrent | `qbittorrent.` | ✅ | ❌ | |
| Alfred | `alfred.` | ✅ | ❌ | |
| Paperless | `paperless.` | ✅ | ❌ | OIDC natif possible |
| OpenHands | `openhands.` | ✅ | ❌ | |
| Homepage | `dashboard.` | ✅ | ❌ | |
| Jellyfin | `jellyfin.` | ❌ | ❌ | ⚠️ Accès sans auth |
| Nextcloud | `nextcloud.` | ❌ | ❌ | OIDC natif possible |
| Immich | `photo.` | ❌ bypass | ✅ | SSO Authelia OIDC |
