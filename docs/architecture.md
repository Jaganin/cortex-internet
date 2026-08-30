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

## Providers: file + Docker

Traefik is configured with two providers at once:

- **File** (`traefik/dynamic/*.yml`) — authoritative for every native/non-Docker
  service (Jeedom, qBittorrent, Alfred, Synology...) and for any Docker service not
  yet migrated to labels. This stays the default for new services unless they run in
  a container on the `proxy` network.
- **Docker** (`traefik.yml`, `providers.docker`) — opt-in via `traefik.enable=true`
  labels only (`exposedByDefault: false`), scoped to the `proxy` network, socket
  mounted **read-only**. Lets containers sharing a service label be aggregated into
  one load balancer with multiple backends — the mechanism blue/green deploys (e.g.
  MyCGP, Jaganin/MyCGP#459) rely on.

### Why the Docker provider was off for 3 months

It was disabled in commit `628acda` after "client version 1.24 is too old" errors.
That looked like a Docker API version mismatch and a `DOCKER_API_VERSION=1.52` pin was
tried first — it didn't help, because the real cause was a bug in Traefik's vendored
Docker SDK (pre-3.6): it defaults to requesting API 1.24 regardless of env vars, and
Docker Engine 29 rejects any client below its `MinAPIVersion` outright, breaking
negotiation entirely. No config on the Traefik side could route around it. The fix
shipped upstream in Traefik v3.6 with corrected API negotiation. Confirmed directly
against this host (Docker Engine 29.1.3, API 1.52) by running a disposable
`traefik:v3.3` container against the real socket (fails, same 1.24 error) and a
`traefik:v3.6` one (connects and lists containers correctly) — hence the version bump
to `v3.6` alongside re-enabling the provider.

### Rollback

Traefik is the household's single internet entry point, so a bad config here takes
everything down at once. If the Docker provider or the v3.6 bump misbehaves in
production:

```bash
cd /opt/cortex-internet
git revert <this-PR's-merge-commit>   # or: git checkout <previous-commit> -- docker-compose.yml traefik/traefik.yml
docker compose up -d traefik
```

This drops back to file-provider-only routing (`traefik:v3.3`, no socket mount) —
every service that was already on the file provider is unaffected, since it was never
the file provider that changed. Only services migrated to Docker labels (currently
just the leboncoin-mcp canary) need their `services.yml` entry to still exist to fall
back to — which is exactly why the file entry isn't deleted until the label-based
router has been validated against real traffic.

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
