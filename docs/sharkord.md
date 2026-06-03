# Sharkord

Self-hosted Discord alternative with voice, video, text and screen sharing.

- GitHub: [Sharkord/sharkord](https://github.com/Sharkord/sharkord)
- Version: v0.0.22 (alpha)
- Interface: https://sharkord.jaganin.duckdns.org

## Ports

| Port      | Protocol | Role                        | Exposed via        |
|-----------|----------|-----------------------------|--------------------|
| 4991      | TCP      | Web interface               | Traefik HTTPS      |
| 40000     | TCP      | Media (voice/video)         | Direct (Freebox)   |
| 40000     | UDP      | Media (voice/video)         | Direct (Freebox)   |

Port forwarding configured on the Freebox: `40000 TCP+UDP → 192.168.1.120`.

## Data

Data is stored on the Synology NAS via NFS:

- Synology share: `/volume1/sharkorb` (192.168.1.5)
- Mount point on Cortex: `/mnt/synology/sharkorb`
- fstab entry: `192.168.1.5:/volume1/sharkorb  /mnt/synology/sharkorb  nfs  defaults  0  0`
- Mounted into the container at: `/home/bun/.config/sharkord`

## Admin access

On first boot, an owner token was generated. To gain admin privileges:

1. Open https://sharkord.jaganin.duckdns.org in a browser
2. Open the dev console (F12 → Console)
3. Run: `useToken("019e8f1e-6f64-7000-8b63-6fb8f30f994c")`

> **Keep this token secret** — anyone with it can take full control of the server.

## Docker

Defined in `docker-compose.yml` alongside Traefik, Authelia and Homepage.

```yaml
sharkord:
  image: sharkord/sharkord:latest
  container_name: sharkord
  restart: unless-stopped
  networks:
    - proxy
  ports:
    - "40000:40000/tcp"
    - "40000:40000/udp"
  volumes:
    - /mnt/synology/sharkorb:/home/bun/.config/sharkord
```

## Traefik

- Service: `http://sharkord:4991`
- Router: `sharkord.jaganin.duckdns.org` → HTTPS, no Authelia (users need direct access)
