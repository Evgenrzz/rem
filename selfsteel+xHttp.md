.env
```
SELF_STEAL_DOMAIN=node.temnoevpn.net
SELF_STEAL_PORT=8443
```
------------**#selfsteel**------------<br/>
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
{
    auto_https disable_redirects
}

squid-game.su:443 {
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

------------**#Xray config**--------------------
```
{
  "log": {
    "loglevel": "info"
  },
  "inbounds": [
    {
      "tag": "VLESS_XHTTP",
      "port": 8443,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "sniffing": {
        "enabled": true,
        "routeOnly": false,
        "destOverride": [
          "http",
          "tls",
          "quic",
          "fakedns"
        ],
        "metadataOnly": false
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "mode": "auto",
          "path": "/xhttppath/",
          "extra": {
            "noSSEHeader": true,
            "xPaddingBytes": "100-1000",
            "scMaxBufferedPosts": 30,
            "scMaxEachPostBytes": 1000000,
            "scMaxConcurrentPosts": "100-200",
            "scMinPostsIntervalMs": "10-30",
            "scStreamUpServerSecs": "20-80"
          }
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "DIRECT",
      "protocol": "freedom"
    },
    {
      "tag": "BLOCK",
      "protocol": "blackhole"
    }
  ],
  "routing": {
    "rules": [
      {
        "ip": [
          "geoip:private"
        ],
        "type": "field",
        "outboundTag": "BLOCK"
      },
      {
        "type": "field",
        "domain": [
          "geosite:private"
        ],
        "outboundTag": "BLOCK"
      },
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "BLOCK"
      }
    ]
  }
}
```
