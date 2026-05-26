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
        - authelia@docker
        - secure-headers@file
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

Remove the `authelia@docker` middleware from the Traefik router as well.
