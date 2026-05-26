# Architecture

## Network flow

```
[Browser] → HTTPS → [Freebox port forwarding]
                              │
                              ▼
                    [Cortex :443 — Traefik]
                              │
               ┌──────────────┼──────────────┐
               │              │              │
          auth.*         traefik.*     qbittorrent.*
               │              │              │
          [Authelia]    [Traefik UI]  [Authelia check]
               │                            │
          login page                  [qBittorrent :8080]
```

## TLS

Traefik handles wildcard certificates via **Let's Encrypt DNS-01** challenge using the DuckDNS provider (`lego`).

- Single wildcard cert covers all `*.jaganin.duckdns.org`
- Cert stored in a Docker volume (`traefik-certs`)
- Auto-renewed before expiry

## Authentication flow

1. Browser requests `qbittorrent.jaganin.duckdns.org`
2. Traefik calls Authelia's ForwardAuth endpoint
3. Authelia checks the session cookie
4. If not authenticated → redirect to `auth.jaganin.duckdns.org`
5. User logs in with username + TOTP code
6. Authelia sets a session cookie on `.jaganin.duckdns.org` (shared across all subdomains)
7. Traefik forwards the request to the backend

## Docker network

All containers share the `proxy` Docker network. Non-Docker services (qBittorrent, OpenClaw running natively) are reached via `localhost` or `host.docker.internal` from within Traefik's dynamic config.

## Security posture

| Threat                   | Mitigation                            |
|--------------------------|---------------------------------------|
| Unprotected endpoints    | Authelia ForwardAuth on all routes    |
| Brute force              | Authelia regulation (5 tries → ban)  |
| Weak auth                | TOTP 2FA required                     |
| HTTP                     | Redirect to HTTPS (Traefik)           |
| Clickjacking / XSS       | Security headers middleware           |
| Certificate exposure     | acme.json chmod 600, gitignored       |
| Secret leaks             | .env gitignored, Docker secrets ready |
