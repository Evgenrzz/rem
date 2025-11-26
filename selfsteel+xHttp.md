------------**selfsteel**------------<br/>
cd /opt/selfsteel  <br/>
nano docker-compose.yml
```
services:
  caddy:
    image: caddy:latest
    container_name: caddy-remnawave
    restart: unless-stopped
    network_mode: "host"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./logs:/var/log/caddy
      - /var/www/html:/var/www/html:ro
      - caddy_data:/data
      - caddy_config:/config
    env_file:
      - .env

volumes:
  caddy_data:
  caddy_config:
```

------------**#Caddyfile**--------------------
```
http://{$SELF_STEAL_DOMAIN} {
    redir https://{$SELF_STEAL_DOMAIN}{uri} permanent
}

https://{$SELF_STEAL_DOMAIN} {
    # Placeholder сайт на корне
    root * /var/www/html

    # Проксирование xhttp трафика на Xray
    handle /xhttppath/* {
        reverse_proxy 127.0.0.1:8443 {
            header_up Host {host}
            header_up X-Real-IP {remote}

            # Важные настройки для xhttp
            transport http {
                versions h2c 1.1
                keepalive off
                compression off
                read_timeout 5m
                write_timeout 5m
            }

            flush_interval -1
        }
    }

    # Показать сайт на корне
    handle {
        try_files {path} /index.html
        file_server
    }
}
```
