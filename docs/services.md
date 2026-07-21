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

### Notes — Paperless-ngx OIDC specifics (allauth 65.x)

- Use `client_secret_basic` in the Authelia client (allauth default — unlike most other clients that use `client_secret_post`)
- Redirect URI: `https://paperless.jaganin.duckdns.org/accounts/oidc/authelia/login/callback/`
- The OIDC provider module is **not** included by default: add `PAPERLESS_APPS: allauth.socialaccount.providers.openid_connect`
- Configure via env:
  ```yaml
  PAPERLESS_APPS: allauth.socialaccount.providers.openid_connect
  PAPERLESS_REDIRECT_LOGIN_TO_SSO: "true"
  PAPERLESS_DISABLE_REGULAR_LOGIN: "true"
  PAPERLESS_ACCOUNT_ALLOW_SIGNUPS: "false"
  PAPERLESS_SOCIAL_AUTO_SIGNUP: "false"
  PAPERLESS_SOCIALACCOUNT_PROVIDERS: >-
    {"openid_connect": {"APPS": [{"provider_id": "authelia", "name": "Authelia",
    "client_id": "paperless", "secret": "<plain_secret>",
    "settings": {"server_url": "https://auth.jaganin.duckdns.org"}}]}}
  ```
- Linking OIDC to an existing user: allauth 65.x does not auto-connect by email.
  Workaround: temporarily enable signups, complete the OIDC flow once (creates a temp user),
  then in Django shell transfer the `SocialAccount` to the real user and delete the temp user.

### Notes — Nextcloud OIDC specifics

- Include the `groups` scope in the client definition (Nextcloud's `user_oidc` requests it)
- Redirect URI: `https://nextcloud.jaganin.duckdns.org/apps/user_oidc/code`
- App: **OpenID Connect user backend** (`user_oidc`), discovery endpoint: `https://auth.jaganin.duckdns.org/.well-known/openid-configuration`
- Homepage widget must use the **public HTTPS URL** (`https://nextcloud.jaganin.duckdns.org`), not the internal HTTP port — Nextcloud enforces `Secure` cookies when `overwriteprotocol: https` is set
- Configure `trusted_proxies` to avoid brute-force throttling on the Docker/LAN range:
  ```bash
  occ config:system:set trusted_proxies 0 --value=172.16.0.0/12
  occ config:system:set trusted_proxies 1 --value=192.168.0.0/16
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
| Paperless | `paperless.` | ❌ bypass | ✅ | SSO Authelia OIDC (allauth 65.x) |
| OpenHands | `openhands.` | ✅ | ❌ | |
| Homepage | `dashboard.` | ✅ | ❌ | |
| Jellyfin | `jellyfin.` | ❌ | ❌ | ⚠️ Accès sans auth |
| Nextcloud | `nextcloud.` | ❌ bypass | ✅ | SSO Authelia OIDC (`user_oidc`) |
| Immich | `photo.` | ❌ bypass | ✅ | SSO Authelia OIDC |
| MyCGP | `mycgp.` | ✅ | ❌ | Cortex natif, port 8020 |
| leboncoin-mcp | `leboncoin.` | ❌ Basic Auth | ❌ | Docker (build from `./lbc-mcp`), port 8040, transport MCP SSE. Basic Auth instead of Authelia — MCP clients can't do interactive TOTP login |
